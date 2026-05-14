import SwiftUI

struct SubscriptionsView: View {
    @EnvironmentObject var data: DataStore
    @State private var showAdd = false

    var monthlyExpense: Double {
        data.subscriptions.filter { $0.active && $0.type == .expense }
            .reduce(0) { $0 + $1.monthlyEquivalent }
    }
    var monthlyIncome: Double {
        data.subscriptions.filter { $0.active && $0.type == .income }
            .reduce(0) { $0 + $1.monthlyEquivalent }
    }

    var body: some View {
        NavigationStack {
            Group {
                if data.subscriptions.isEmpty {
                    ContentUnavailableView(
                        "Brak pozycji cyklicznych",
                        systemImage: "repeat",
                        description: Text("Dodaj subskrypcję, wydatek lub przychód cykliczny plusem w prawym górnym rogu.")
                    )
                } else {
                    List {
                        Section {
                            VStack(spacing: 6) {
                                HStack {
                                    Text("Wydatki / mies.").font(.caption).foregroundStyle(.secondary)
                                    Spacer()
                                    Text(monthlyExpense, format: .currency(code: "PLN")).foregroundStyle(.red).monospacedDigit()
                                }
                                HStack {
                                    Text("Przychody / mies.").font(.caption).foregroundStyle(.secondary)
                                    Spacer()
                                    Text(monthlyIncome, format: .currency(code: "PLN")).foregroundStyle(.green).monospacedDigit()
                                }
                                Divider()
                                HStack {
                                    Text("Saldo").font(.subheadline.bold())
                                    Spacer()
                                    Text(monthlyIncome - monthlyExpense, format: .currency(code: "PLN"))
                                        .foregroundStyle(monthlyIncome - monthlyExpense >= 0 ? .green : .red)
                                        .bold().monospacedDigit()
                                }
                            }
                        }
                        Section("Pozycje") {
                            ForEach(data.subscriptions) { sub in
                                SubscriptionRow(sub: sub)
                            }
                            .onDelete { idx in
                                let toDelete = idx.map { data.subscriptions[$0] }
                                Task { for s in toDelete { await data.deleteSubscription(s) } }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Cykliczne")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showAdd = true } label: { Image(systemName: "plus") }
                }
            }
            .sheet(isPresented: $showAdd) { AddSubscriptionSheet() }
        }
    }
}

private struct SubscriptionRow: View {
    @EnvironmentObject var data: DataStore
    let sub: Subscription

    var body: some View {
        let isIncome = sub.type == .income
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(Color(hex: sub.color).opacity(0.2))
                Image(systemName: isIncome ? "arrow.down.circle.fill" : sub.icon)
                    .foregroundStyle(isIncome ? Color.green : Color(hex: sub.color))
            }
            .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(sub.name).font(.body).strikethrough(!sub.active)
                    if isIncome {
                        Text("Przychód").font(.caption2).bold()
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Color.green.opacity(0.15), in: Capsule())
                            .foregroundStyle(.green)
                    }
                }
                if let acc = data.account(id: sub.account_id) {
                    Text("\(sub.nextBillingDateValue, style: .date) · \(acc.name)")
                        .font(.caption).foregroundStyle(.secondary)
                } else {
                    Text(sub.nextBillingDateValue, style: .date)
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            VStack(alignment: .trailing) {
                Text("\(isIncome ? "+" : "")\(sub.amount, format: .currency(code: "PLN"))")
                    .bold()
                    .foregroundStyle(isIncome ? .green : .primary)
                Text(sub.billing_cycle.label).font(.caption2).foregroundStyle(.secondary)
            }
        }
        .swipeActions(edge: .leading) {
            Button {
                Task { await data.toggleSubscriptionActive(sub) }
            } label: {
                Label(sub.active ? "Pauza" : "Wznów", systemImage: sub.active ? "pause.circle" : "play.circle")
            }
            .tint(sub.active ? .orange : .green)
        }
    }
}

struct AddSubscriptionSheet: View {
    @EnvironmentObject var data: DataStore
    @Environment(\.dismiss) private var dismiss

    @State private var type: CategoryType = .expense
    @State private var name = ""
    @State private var amount: Double?
    @State private var cycle: BillingCycle = .monthly
    @State private var nextDate = Date()
    @State private var categoryId: UUID?
    @State private var accountId: UUID?
    @State private var notes = ""
    @State private var hasFirstPayment = false
    @State private var firstPaymentDate = Date()

    var body: some View {
        NavigationStack {
            Form {
                Section("Typ") {
                    Picker("Typ", selection: $type) {
                        Text("Wydatek").tag(CategoryType.expense)
                        Text("Przychód").tag(CategoryType.income)
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: type) { _, _ in categoryId = nil }
                }
                Section("Nazwa") {
                    TextField(type == .income ? "np. Wypłata" : "np. Netflix, Rata kredytu", text: $name)
                }
                Section(type == .income ? "Wpływ" : "Płatność") {
                    TextField("Kwota", value: $amount, format: .number)
                        .keyboardType(.decimalPad)
                    Picker("Cykl", selection: $cycle) {
                        ForEach(BillingCycle.allCases) { Text($0.label).tag($0) }
                    }
                    DatePicker(type == .income ? "Najbliższy wpływ" : "Następna płatność", selection: $nextDate, displayedComponents: .date)
                }
                Section {
                    Toggle(type == .income ? "Już otrzymałem pierwszy wpływ" : "Już zapłaciłem pierwszą ratę", isOn: $hasFirstPayment)
                    if hasFirstPayment {
                        DatePicker("Data", selection: $firstPaymentDate, displayedComponents: .date)
                    }
                } footer: {
                    if hasFirstPayment {
                        Text(type == .income
                             ? "Utworzymy transakcję historyczną i dodamy kwotę do wybranego konta."
                             : "Utworzymy transakcję historyczną i odejmiemy kwotę od wybranego konta.")
                    }
                }
                Section {
                    Picker(type == .income ? "Konto (na które wpływa)" : "Konto (z którego pobierać)", selection: $accountId) {
                        Text("Brak").tag(UUID?.none)
                        ForEach(data.accounts) { a in
                            Text(a.name).tag(Optional(a.id))
                        }
                    }
                    Picker("Kategoria", selection: $categoryId) {
                        Text("Brak").tag(UUID?.none)
                        ForEach(data.categories.filter { $0.type == type }) { c in
                            Label(c.name, systemImage: c.icon).tag(Optional(c.id))
                        }
                    }
                    TextField("Notatka", text: $notes, axis: .vertical)
                }
            }
            .navigationTitle("Nowa subskrypcja")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                if accountId == nil,
                   let last = AppDefaults.lastAccountId,
                   data.accounts.contains(where: { $0.id == last }) {
                    accountId = last
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Anuluj") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Zapisz") {
                        let v = amount ?? 0
                        let firstDate = hasFirstPayment ? firstPaymentDate : nil
                        Task {
                            await data.addSubscription(
                                name: name,
                                amount: v,
                                cycle: cycle,
                                nextDate: nextDate,
                                categoryId: categoryId,
                                accountId: accountId,
                                notes: notes.isEmpty ? nil : notes,
                                type: type,
                                firstPaymentDate: firstDate
                            )
                            if let aid = accountId { AppDefaults.lastAccountId = aid }
                            dismiss()
                        }
                    }
                    .disabled(name.isEmpty || (amount ?? 0) <= 0)
                }
            }
        }
    }
}
