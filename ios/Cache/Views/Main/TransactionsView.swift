import SwiftUI

struct TransactionsView: View {
    @EnvironmentObject var data: DataStore
    @State private var showAdd = false
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
            .sheet(isPresented: $showAdd) { AddTransactionSheet() }
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

struct AddTransactionSheet: View {
    @EnvironmentObject var data: DataStore
    @Environment(\.dismiss) private var dismiss

    @State private var amount: Double?
    @State private var description = ""
    @State private var date = Date()
    @State private var categoryId: UUID?
    @State private var accountId: UUID?
    @State private var isExpense = true

    var body: some View {
        NavigationStack {
            Form {
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
            }
            .navigationTitle("Nowa transakcja")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Anuluj") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Zapisz") {
                        let v = amount ?? 0
                        let signed = isExpense ? -abs(v) : abs(v)
                        Task {
                            await data.addTransaction(amount: signed, description: description, date: date, categoryId: categoryId, accountId: accountId)
                            dismiss()
                        }
                    }
                    .disabled((amount ?? 0) <= 0)
                }
            }
        }
    }

    var filteredCategories: [Category] {
        data.categories.filter { $0.type == (isExpense ? .expense : .income) }
    }
}
