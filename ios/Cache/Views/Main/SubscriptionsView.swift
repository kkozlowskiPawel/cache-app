import SwiftUI

struct SubscriptionsView: View {
    @EnvironmentObject var data: DataStore
    @State private var showAdd = false

    var body: some View {
        NavigationStack {
            Group {
                if data.subscriptions.isEmpty {
                    ContentUnavailableView(
                        "Brak subskrypcji",
                        systemImage: "repeat",
                        description: Text("Dodaj subskrypcje plusem w prawym górnym rogu.")
                    )
                } else {
                    List {
                        Section {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text("Łącznie miesięcznie").font(.subheadline).foregroundStyle(.secondary)
                                    Text(data.monthlySubscriptionsTotal, format: .currency(code: "PLN"))
                                        .font(.title.bold())
                                }
                                Spacer()
                                VStack(alignment: .trailing) {
                                    Text("Rocznie").font(.subheadline).foregroundStyle(.secondary)
                                    Text(data.monthlySubscriptionsTotal * 12, format: .currency(code: "PLN"))
                                        .font(.title3)
                                }
                            }
                        }
                        Section("Subskrypcje") {
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
            .navigationTitle("Subskrypcje")
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
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(Color(hex: sub.color).opacity(0.2))
                Image(systemName: sub.icon).foregroundStyle(Color(hex: sub.color))
            }
            .frame(width: 40, height: 40)

            VStack(alignment: .leading) {
                Text(sub.name).font(.body).strikethrough(!sub.active)
                Text("Następna: \(sub.nextBillingDateValue, style: .date)")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing) {
                Text(sub.amount, format: .currency(code: "PLN")).bold()
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
                Section("Nazwa") {
                    TextField("np. Netflix, Spotify", text: $name)
                }
                Section("Płatność") {
                    TextField("Kwota", value: $amount, format: .number)
                        .keyboardType(.decimalPad)
                    Picker("Cykl", selection: $cycle) {
                        ForEach(BillingCycle.allCases) { Text($0.label).tag($0) }
                    }
                    DatePicker("Następna płatność", selection: $nextDate, displayedComponents: .date)
                }
                Section {
                    Toggle("Już zapłaciłem pierwszą ratę", isOn: $hasFirstPayment)
                    if hasFirstPayment {
                        DatePicker("Data pierwszej płatności", selection: $firstPaymentDate, displayedComponents: .date)
                    }
                } footer: {
                    if hasFirstPayment {
                        Text("Utworzymy transakcję historyczną i odejmiemy kwotę od wybranego konta.")
                    }
                }
                Section {
                    Picker("Konto (z którego pobierać)", selection: $accountId) {
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
