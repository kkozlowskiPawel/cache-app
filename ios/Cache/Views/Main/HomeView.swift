import SwiftUI
import Charts

struct HomeView: View {
    @EnvironmentObject var data: DataStore

    var savings: Double { data.monthlyIncome - data.monthlyExpenses }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    summaryCard
                    netWorthCard
                    spendingChartCard
                    upcomingBillsCard
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Dashboard")
            .refreshable { await data.loadAll() }
        }
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Ten miesiąc").font(.headline)
            HStack {
                statTile(title: "Przychód",  value: data.monthlyIncome,   color: .green,  icon: "arrow.down.circle.fill")
                statTile(title: "Wydatki",   value: data.monthlyExpenses, color: .red,    icon: "arrow.up.circle.fill")
                statTile(title: "Oszczędn.", value: savings,              color: savings >= 0 ? .blue : .orange, icon: "banknote.fill")
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    private func statTile(title: String, value: Double, color: Color, icon: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon).foregroundStyle(color)
            Text(value, format: .currency(code: "PLN")).font(.headline).lineLimit(1).minimumScaleFactor(0.6)
            Text(title).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var netWorthCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Wartość netto").font(.headline)
            Text(data.netWorth, format: .currency(code: "PLN"))
                .font(.system(size: 32, weight: .bold, design: .rounded))
            Text("\(data.accounts.count) kont")
                .font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    private var spendingChartCard: some View {
        let byCat = Dictionary(grouping: data.transactions.filter { $0.amount < 0 }) { $0.category_id }
            .compactMap { (cid, txs) -> (Category, Double)? in
                guard let cid, let cat = data.category(id: cid) else { return nil }
                return (cat, txs.reduce(0) { $0 + abs($1.amount) })
            }
            .sorted { $0.1 > $1.1 }
            .prefix(6)

        return VStack(alignment: .leading, spacing: 12) {
            Text("Wydatki wg kategorii").font(.headline)
            if byCat.isEmpty {
                Text("Brak danych — dodaj transakcje.")
                    .font(.subheadline).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 120)
            } else {
                Chart {
                    ForEach(Array(byCat), id: \.0.id) { (cat, total) in
                        BarMark(
                            x: .value("Kwota", total),
                            y: .value("Kategoria", cat.name)
                        )
                        .foregroundStyle(Color(hex: cat.color))
                        .cornerRadius(6)
                    }
                }
                .frame(height: CGFloat(byCat.count) * 36 + 20)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    private var upcomingBillsCard: some View {
        let upcoming = data.bills.filter { !$0.paid && $0.dueDateValue >= Calendar.current.startOfDay(for: Date()) }.prefix(5)
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Nadchodzące rachunki").font(.headline)
                Spacer()
                NavigationLink("Wszystkie") { BillsView() }
                    .font(.footnote)
            }
            if upcoming.isEmpty {
                Text("Brak nadchodzących rachunków.")
                    .font(.subheadline).foregroundStyle(.secondary)
            } else {
                ForEach(Array(upcoming)) { bill in
                    HStack {
                        Image(systemName: "calendar.badge.clock").foregroundStyle(.orange)
                        VStack(alignment: .leading) {
                            Text(bill.name)
                            Text(bill.dueDateValue, style: .date).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(bill.amount, format: .currency(code: "PLN")).bold()
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }
}
