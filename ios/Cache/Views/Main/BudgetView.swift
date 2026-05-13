import SwiftUI

struct BudgetView: View {
    @EnvironmentObject var data: DataStore
    @State private var tab = 0
    @State private var editingBudget: Category?
    @State private var showAddGoal = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("", selection: $tab) {
                    Text("Budżety").tag(0)
                    Text("Cele").tag(1)
                }
                .pickerStyle(.segmented)
                .padding()

                if tab == 0 { budgetsList } else { goalsList }
            }
            .navigationTitle(tab == 0 ? "Budżet" : "Cele")
            .toolbar {
                if tab == 1 {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { showAddGoal = true } label: { Image(systemName: "plus") }
                    }
                }
            }
            .sheet(item: $editingBudget) { cat in
                EditBudgetSheet(category: cat)
            }
            .sheet(isPresented: $showAddGoal) { AddGoalSheet() }
        }
    }

    @ViewBuilder
    private var budgetsList: some View {
        List {
            ForEach(data.categories.filter { $0.type == .expense }) { cat in
                let budget = data.budgets.first { $0.category_id == cat.id }
                let spent = data.currentMonthExpense(categoryId: cat.id)
                BudgetRow(category: cat, budget: budget, spent: spent)
                    .contentShape(Rectangle())
                    .onTapGesture { editingBudget = cat }
            }
        }
        .listStyle(.insetGrouped)
    }

    @ViewBuilder
    private var goalsList: some View {
        if data.goals.isEmpty {
            ContentUnavailableView(
                "Brak celów",
                systemImage: "target",
                description: Text("Dodaj cel oszczędnościowy plusem w prawym górnym rogu.")
            )
        } else {
            List {
                ForEach(data.goals) { goal in
                    GoalRow(goal: goal)
                }
                .onDelete { idx in
                    let toDel = idx.map { data.goals[$0] }
                    Task { for g in toDel { await data.deleteGoal(g) } }
                }
            }
            .listStyle(.insetGrouped)
        }
    }
}

private struct BudgetRow: View {
    let category: Category
    let budget: Budget?
    let spent: Double

    var progress: Double {
        guard let b = budget, b.amount > 0 else { return 0 }
        return min(spent / b.amount, 1.0)
    }
    var overBudget: Bool {
        guard let b = budget else { return false }
        return spent > b.amount
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: category.icon).foregroundStyle(Color(hex: category.color))
                Text(category.name).bold()
                Spacer()
                if let b = budget {
                    Text("\(spent, format: .currency(code: "PLN")) / \(b.amount, format: .currency(code: "PLN"))")
                        .font(.caption)
                        .foregroundStyle(overBudget ? .red : .secondary)
                } else {
                    Text("Ustaw budżet").font(.caption).foregroundStyle(.tint)
                }
            }
            if budget != nil {
                ProgressView(value: progress)
                    .tint(overBudget ? .red : Color(hex: category.color))
            }
        }
        .padding(.vertical, 4)
    }
}

private struct GoalRow: View {
    @EnvironmentObject var data: DataStore
    let goal: Goal
    @State private var showEdit = false
    @State private var newAmount: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: goal.icon).foregroundStyle(Color(hex: goal.color))
                Text(goal.name).bold()
                Spacer()
                Text("\(Int(goal.progress * 100))%")
                    .font(.caption).foregroundStyle(.secondary)
            }
            ProgressView(value: goal.progress).tint(Color(hex: goal.color))
            HStack {
                Text("\(goal.current_amount, format: .currency(code: "PLN")) / \(goal.target_amount, format: .currency(code: "PLN"))")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("Aktualizuj") {
                    newAmount = goal.current_amount > 0 ? String(format: "%g", goal.current_amount) : ""
                    showEdit = true
                }
                .font(.caption)
            }
        }
        .padding(.vertical, 4)
        .alert("Aktualizuj kwotę", isPresented: $showEdit) {
            TextField("Kwota", text: $newAmount).keyboardType(.decimalPad)
            Button("Zapisz") {
                if let v = Double(newAmount.replacingOccurrences(of: ",", with: ".")) {
                    Task { await data.updateGoalCurrent(goal, current: v) }
                }
            }
            Button("Anuluj", role: .cancel) {}
        }
    }
}

struct EditBudgetSheet: View {
    @EnvironmentObject var data: DataStore
    @Environment(\.dismiss) private var dismiss
    let category: Category
    @State private var amount: Double?
    @State private var period: BudgetPeriod = .monthly

    var body: some View {
        NavigationStack {
            Form {
                Section("Kategoria") {
                    Label(category.name, systemImage: category.icon)
                }
                Section("Budżet") {
                    TextField("Kwota", value: $amount, format: .number)
                        .keyboardType(.decimalPad)
                    Picker("Okres", selection: $period) {
                        ForEach(BudgetPeriod.allCases) { Text($0.label).tag($0) }
                    }
                }
                if let existing = data.budgets.first(where: { $0.category_id == category.id }) {
                    Section {
                        Button("Usuń budżet", role: .destructive) {
                            Task { await data.deleteBudget(existing); dismiss() }
                        }
                    }
                }
            }
            .navigationTitle("Budżet")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Anuluj") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Zapisz") {
                        let v = amount ?? 0
                        Task { await data.setBudget(categoryId: category.id, amount: v, period: period); dismiss() }
                    }
                    .disabled((amount ?? 0) <= 0)
                }
            }
            .onAppear {
                if let b = data.budgets.first(where: { $0.category_id == category.id }) {
                    amount = b.amount; period = b.period
                }
            }
        }
    }
}

struct AddGoalSheet: View {
    @EnvironmentObject var data: DataStore
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var target: Double?
    @State private var current: Double?
    @State private var hasTargetDate = false
    @State private var targetDate = Date().addingTimeInterval(60*60*24*180)
    @State private var icon = "target"
    @State private var color = "#007AFF"

    let icons = ["target", "house.fill", "car.fill", "airplane", "graduationcap.fill", "gift.fill", "heart.fill", "star.fill"]
    let colors = ["#007AFF", "#34C759", "#FF9500", "#FF2D55", "#AF52DE", "#5856D6", "#FF3B30"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Nazwa") { TextField("np. Wakacje", text: $name) }
                Section("Kwoty") {
                    TextField("Kwota docelowa", value: $target, format: .number).keyboardType(.decimalPad)
                    TextField("Już odłożone (opcjonalnie)", value: $current, format: .number).keyboardType(.decimalPad)
                }
                Section("Termin") {
                    Toggle("Ustaw datę", isOn: $hasTargetDate)
                    if hasTargetDate {
                        DatePicker("Data", selection: $targetDate, displayedComponents: .date)
                    }
                }
                Section("Ikona") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4)) {
                        ForEach(icons, id: \.self) { ic in
                            Image(systemName: ic)
                                .font(.title2)
                                .padding(8)
                                .background(icon == ic ? Color.accentColor.opacity(0.2) : .clear, in: Circle())
                                .onTapGesture { icon = ic }
                        }
                    }
                }
                Section("Kolor") {
                    HStack {
                        ForEach(colors, id: \.self) { c in
                            Circle()
                                .fill(Color(hex: c))
                                .frame(width: 30, height: 30)
                                .overlay(Circle().stroke(.primary, lineWidth: color == c ? 2 : 0))
                                .onTapGesture { color = c }
                        }
                    }
                }
            }
            .navigationTitle("Nowy cel")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Anuluj") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Zapisz") {
                        let t = target ?? 0
                        let c = current ?? 0
                        Task {
                            await data.addGoal(name: name, target: t, current: c, targetDate: hasTargetDate ? targetDate : nil, icon: icon, color: color)
                            dismiss()
                        }
                    }
                    .disabled(name.isEmpty || (target ?? 0) <= 0)
                }
            }
        }
    }
}
