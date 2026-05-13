import SwiftUI

struct BillsView: View {
    @EnvironmentObject var data: DataStore
    @State private var showAdd = false

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
                    ForEach(data.bills) { bill in
                        HStack {
                            Button {
                                Task { await data.togglePaid(bill) }
                            } label: {
                                Image(systemName: bill.paid ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(bill.paid ? .green : .secondary)
                            }
                            .buttonStyle(.plain)
                            VStack(alignment: .leading) {
                                Text(bill.name).strikethrough(bill.paid)
                                Text(bill.dueDateValue, style: .date).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(bill.amount, format: .currency(code: "PLN"))
                        }
                    }
                    .onDelete { idx in
                        let toDel = idx.map { data.bills[$0] }
                        Task { for b in toDel { await data.deleteBill(b) } }
                    }
                }
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

struct AddBillSheet: View {
    @EnvironmentObject var data: DataStore
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var amount: Double?
    @State private var dueDate = Date()
    @State private var categoryId: UUID?
    @State private var reminderDays = 3

    var body: some View {
        NavigationStack {
            Form {
                Section("Rachunek") {
                    TextField("Nazwa", text: $name)
                    TextField("Kwota", value: $amount, format: .number).keyboardType(.decimalPad)
                    DatePicker("Termin", selection: $dueDate, displayedComponents: .date)
                }
                Section("Przypomnienie") {
                    Stepper("\(reminderDays) dni wcześniej", value: $reminderDays, in: 0...30)
                }
                Section("Kategoria") {
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
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Anuluj") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Zapisz") {
                        let v = amount ?? 0
                        Task {
                            await data.addBill(name: name, amount: v, dueDate: dueDate, categoryId: categoryId, reminderDays: reminderDays)
                            dismiss()
                        }
                    }
                    .disabled(name.isEmpty || (amount ?? 0) <= 0)
                }
            }
        }
    }
}
