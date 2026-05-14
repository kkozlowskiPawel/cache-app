import SwiftUI

struct TransactionsView: View {
    @EnvironmentObject var data: DataStore
    @State private var showAdd = false
    @State private var editing: Transaction?
    @State private var filterCategoryId: UUID?

    var filtered: [Transaction] {
        guard let cid = filterCategoryId else { return data.transactions }
        return data.transactions.filter { $0.category_id == cid }
    }

    var grouped: [(String, [Transaction])] {
        let groups = Dictionary(grouping: filtered) { $0.date }
        return groups.sorted { $0.key > $1.key }.map { ($0.key, $0.value) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if data.transactions.isEmpty {
                    ContentUnavailableView(
                        "Brak transakcji",
                        systemImage: "list.bullet.rectangle",
                        description: Text("Dodaj pierwszą transakcję plusem w prawym górnym rogu.")
                    )
                } else {
                    List {
                        ForEach(grouped, id: \.0) { (dateStr, txs) in
                            Section(DateOnly.date(from: dateStr).formatted(date: .complete, time: .omitted)) {
                                ForEach(txs) { tx in
                                    TransactionRow(tx: tx)
                                        .contentShape(Rectangle())
                                        .onTapGesture { editing = tx }
                                        .swipeActions(edge: .leading) {
                                            Button {
                                                editing = tx
                                            } label: {
                                                Label("Edytuj", systemImage: "pencil")
                                            }
                                            .tint(.blue)
                                        }
                                }
                                .onDelete { idx in
                                    let toDelete = idx.map { txs[$0] }
                                    Task { for t in toDelete { await data.deleteTransaction(t) } }
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Wydatki")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Button("Wszystkie") { filterCategoryId = nil }
                        Divider()
                        ForEach(data.categories) { cat in
                            Button(cat.name) { filterCategoryId = cat.id }
                        }
                    } label: {
                        Image(systemName: filterCategoryId == nil ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showAdd = true } label: { Image(systemName: "plus") }
                }
            }
            .sheet(isPresented: $showAdd) { TransactionEditorSheet(editing: nil) }
            .sheet(item: $editing) { tx in TransactionEditorSheet(editing: tx) }
            .refreshable { await data.loadAll() }
        }
    }
}

private struct TransactionRow: View {
    @EnvironmentObject var data: DataStore
    let tx: Transaction

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(Color(hex: data.category(id: tx.category_id)?.color ?? "#8E8E93").opacity(0.2))
                Image(systemName: data.category(id: tx.category_id)?.icon ?? "circle.fill")
                    .foregroundStyle(Color(hex: data.category(id: tx.category_id)?.color ?? "#8E8E93"))
            }
            .frame(width: 36, height: 36)

            VStack(alignment: .leading) {
                Text(tx.description.isEmpty ? (data.category(id: tx.category_id)?.name ?? "—") : tx.description)
                if let acc = data.account(id: tx.account_id) {
                    Text(acc.name).font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            Text(tx.amount, format: .currency(code: "PLN"))
                .foregroundStyle(tx.amount < 0 ? .red : .green)
                .monospacedDigit()
        }
    }
}

struct TransactionEditorSheet: View {
    @EnvironmentObject var data: DataStore
    @Environment(\.dismiss) private var dismiss

    let editing: Transaction?

    @State private var amount: Double?
    @State private var description = ""
    @State private var date = Date()
    @State private var categoryId: UUID?
    @State private var accountId: UUID?
    @State private var isExpense = true
    @State private var justSaved = false
    @State private var initialized = false

    private var isEdit: Bool { editing != nil }

    var body: some View {
        NavigationStack {
            Form {
                if justSaved {
                    Section {
                        Label("Zapisano — wpisz kolejną", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                }
                Section("Typ") {
                    Picker("Typ", selection: $isExpense) {
                        Text("Wydatek").tag(true)
                        Text("Przychód").tag(false)
                    }
                    .pickerStyle(.segmented)
                }
                Section("Kwota") {
                    TextField("0.00", value: $amount, format: .number)
                        .keyboardType(.decimalPad)
                }
                Section("Szczegóły") {
                    TextField("Opis (opcjonalny)", text: $description)
                    DatePicker("Data", selection: $date, displayedComponents: .date)
                    Picker("Kategoria", selection: $categoryId) {
                        Text("Brak").tag(UUID?.none)
                        ForEach(filteredCategories) { c in
                            Label(c.name, systemImage: c.icon).tag(Optional(c.id))
                        }
                    }
                    Picker("Konto", selection: $accountId) {
                        Text("Brak").tag(UUID?.none)
                        ForEach(data.accounts) { a in
                            Text(a.name).tag(Optional(a.id))
                        }
                    }
                }
                if !isEdit {
                    Section {
                        Button {
                            save(thenAddAnother: true)
                        } label: {
                            Label("Zapisz i dodaj kolejny", systemImage: "plus.circle")
                                .frame(maxWidth: .infinity)
                        }
                        .disabled((amount ?? 0) <= 0)
                    }
                }
            }
            .navigationTitle(isEdit ? "Edytuj transakcję" : "Nowa transakcja")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                guard !initialized else { return }
                initialized = true
                if let tx = editing {
                    amount = abs(tx.amount)
                    description = tx.description
                    date = tx.dateValue
                    categoryId = tx.category_id
                    accountId = tx.account_id
                    isExpense = tx.amount < 0
                } else if accountId == nil,
                          let last = AppDefaults.lastAccountId,
                          data.accounts.contains(where: { $0.id == last }) {
                    accountId = last
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Anuluj") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Zapisz") { save(thenAddAnother: false) }
                        .disabled((amount ?? 0) <= 0)
                }
            }
        }
    }

    private func save(thenAddAnother: Bool) {
        let v = amount ?? 0
        guard v > 0 else { return }
        let signed = isExpense ? -abs(v) : abs(v)
        Task {
            if let tx = editing {
                await data.updateTransaction(tx, amount: signed, description: description, date: date, categoryId: categoryId, accountId: accountId)
            } else {
                await data.addTransaction(amount: signed, description: description, date: date, categoryId: categoryId, accountId: accountId)
            }
            if let aid = accountId { AppDefaults.lastAccountId = aid }
            if thenAddAnother && !isEdit {
                amount = nil
                description = ""
                justSaved = true
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                justSaved = false
            } else {
                dismiss()
            }
        }
    }

    var filteredCategories: [Category] {
        data.categories.filter { $0.type == (isExpense ? .expense : .income) }
    }
}
