import SwiftUI

struct BillsView: View {
    @EnvironmentObject var data: DataStore
    @State private var showAdd = false

    private var unpaid: [Bill] { data.bills.filter { !$0.paid } }
    private var paid: [Bill]   { data.bills.filter { $0.paid } }

    var body: some View {
        Group {
            if data.bills.isEmpty {
                ContentUnavailableView(
                    "Brak rachunków",
                    systemImage: "doc.text",
                    description: Text("Dodaj rachunek plusem w prawym górnym rogu.")
                )
            } else {
                List {
                    if !unpaid.isEmpty {
                        Section {
                            ForEach(unpaid) { bill in
                                UnpaidBillRow(bill: bill)
                            }
                            .onDelete { idx in
                                let toDel = idx.map { unpaid[$0] }
                                Task { for b in toDel { await data.deleteBill(b) } }
                            }
                        } header: {
                            Text("Do zapłaty")
                        } footer: {
                            Text("Kliknięcie „Zapłać” utworzy transakcję na dzisiejszą datę i zmniejszy saldo wskazanego konta.")
                        }
                    }
                    if !paid.isEmpty {
                        Section {
                            ForEach(paid) { bill in
                                PaidBillRow(bill: bill)
                            }
                            .onDelete { idx in
                                let toDel = idx.map { paid[$0] }
                                Task { for b in toDel { await data.deleteBill(b) } }
                            }
                        } header: {
                            Text("Zapłacone")
                        } footer: {
                            Text("„Cofnij oznaczenie” zmienia tylko status — nie usuwa transakcji. Aby ją cofnąć, usuń z listy wydatków.")
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("Rachunki")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showAdd = true } label: { Image(systemName: "plus") }
            }
        }
        .sheet(isPresented: $showAdd) { AddBillSheet() }
    }
}

private struct UnpaidBillRow: View {
    @EnvironmentObject var data: DataStore
    let bill: Bill

    private var isOverdue: Bool { bill.dueDateValue < Calendar.current.startOfDay(for: Date()) }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: isOverdue ? "exclamationmark.circle.fill" : "calendar.badge.clock")
                .foregroundStyle(isOverdue ? .red : .orange)
                .font(.title3)
            VStack(alignment: .leading, spacing: 2) {
                Text(bill.name)
                HStack(spacing: 4) {
                    Text(bill.dueDateValue, style: .date)
                    if let acc = data.account(id: bill.account_id) {
                        Text("· \(acc.name)")
                    }
                }
                .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text(bill.amount, format: .currency(code: "PLN"))
                .font(.body.monospacedDigit())
                .foregroundStyle(.red)
            Button("Zapłać") {
                Task { await data.payBill(bill) }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .tint(.green)
        }
    }
}

private struct PaidBillRow: View {
    @EnvironmentObject var data: DataStore
    let bill: Bill

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green).font(.title3)
            VStack(alignment: .leading, spacing: 2) {
                Text(bill.name).strikethrough().foregroundStyle(.secondary)
                HStack(spacing: 4) {
                    Text(bill.dueDateValue, style: .date)
                    if let acc = data.account(id: bill.account_id) {
                        Text("· \(acc.name)")
                    }
                }
                .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text(bill.amount, format: .currency(code: "PLN"))
                .font(.body.monospacedDigit())
                .strikethrough()
                .foregroundStyle(.secondary)
        }
        .swipeActions(edge: .leading) {
            Button {
                Task { await data.togglePaid(bill) }
            } label: {
                Label("Cofnij", systemImage: "arrow.uturn.backward")
            }
            .tint(.orange)
        }
    }
}

struct AddBillSheet: View {
    @EnvironmentObject var data: DataStore
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var amount: Double?
    @State private var dueDate = Date()
    @State private var categoryId: UUID?
    @State private var accountId: UUID?
    @State private var reminderDays = 3

    var body: some View {
        NavigationStack {
            Form {
                Section("Rachunek") {
                    TextField("Nazwa (np. Prąd, Szkoła)", text: $name)
                    TextField("Kwota", value: $amount, format: .number).keyboardType(.decimalPad)
                    DatePicker("Termin", selection: $dueDate, displayedComponents: .date)
                }
                Section("Przypomnienie") {
                    Stepper("\(reminderDays) dni wcześniej", value: $reminderDays, in: 0...30)
                } footer: {
                    Text("Lokalne powiadomienie pojawi się o 9:00 wybranego dnia.")
                }
                Section {
                    Picker("Konto (z którego zapłacisz)", selection: $accountId) {
                        Text("Brak").tag(UUID?.none)
                        ForEach(data.accounts) { a in
                            Text(a.name).tag(Optional(a.id))
                        }
                    }
                    Picker("Kategoria", selection: $categoryId) {
                        Text("Brak").tag(UUID?.none)
                        ForEach(data.categories.filter { $0.type == .expense }) { c in
                            Label(c.name, systemImage: c.icon).tag(Optional(c.id))
                        }
                    }
                }
            }
            .navigationTitle("Nowy rachunek")
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
                        Task {
                            await data.addBill(
                                name: name,
                                amount: v,
                                dueDate: dueDate,
                                categoryId: categoryId,
                                accountId: accountId,
                                reminderDays: reminderDays
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
