import SwiftUI
import Charts

struct HomeView: View {
    @EnvironmentObject var data: DataStore

    @State private var selectedCalendarDate: DateComponents? = nil
    @State private var chartMode: ChartMode = .daily

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    monthSummary
                    statsRow
                    calendarCard
                    chartsCard
                    upcomingBillsCard
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Dashboard")
            .refreshable { await data.loadAll() }
        }
    }

    // MARK: - Month summary

    private var savings: Double { data.monthlyIncome - data.monthlyExpenses }

    private var monthSummary: some View {
        DashCard {
            HStack(alignment: .firstTextBaseline) {
                Text("Ten miesiąc").font(.headline)
                Spacer()
                Text(Date(), format: .dateTime.month(.wide).year())
                    .font(.footnote).foregroundStyle(.secondary)
            }
            HStack(spacing: 12) {
                statTile(title: "Przychód",   value: data.monthlyIncome,   color: .green,  icon: "arrow.down.circle.fill")
                statTile(title: "Wydatki",    value: data.monthlyExpenses, color: .red,    icon: "arrow.up.circle.fill")
                statTile(title: "Oszczędn.",  value: savings,              color: savings >= 0 ? .blue : .orange, icon: "banknote.fill")
            }
        }
    }

    private func statTile(title: String, value: Double, color: Color, icon: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon).foregroundStyle(color)
            Text(value, format: .currency(code: "PLN"))
                .font(.headline).lineLimit(1).minimumScaleFactor(0.6)
            Text(title).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Net worth + Subscriptions row

    private var statsRow: some View {
        HStack(spacing: 12) {
            DashCard(compact: true) {
                Text("Wartość netto").font(.subheadline.bold())
                Text(data.netWorth, format: .currency(code: "PLN"))
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .lineLimit(1).minimumScaleFactor(0.6)
                Text("\(data.accounts.count) kont").font(.caption2).foregroundStyle(.secondary)
            }
            DashCard(compact: true) {
                Text("Subskrypcje").font(.subheadline.bold())
                Text(data.monthlySubscriptionsTotal, format: .currency(code: "PLN"))
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .lineLimit(1).minimumScaleFactor(0.6)
                Text("miesięcznie").font(.caption2).foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Calendar

    /// Dictionary <DateComponents(y,m,d) -> suma wydatków>.
    private var dailyExpenseTotals: [DateComponents: Double] {
        let cal = Calendar(identifier: .gregorian)
        var dict: [DateComponents: Double] = [:]
        for tx in data.transactions where tx.amount < 0 {
            let d = tx.dateValue
            let key = DateComponents(
                calendar: cal,
                year: cal.component(.year, from: d),
                month: cal.component(.month, from: d),
                day: cal.component(.day, from: d)
            )
            dict[key, default: 0] += abs(tx.amount)
        }
        return dict
    }

    private var selectedDayTotal: Double? {
        guard let dc = selectedCalendarDate else { return nil }
        let key = DateComponents(
            calendar: Calendar(identifier: .gregorian),
            year: dc.year, month: dc.month, day: dc.day
        )
        return dailyExpenseTotals[key]
    }

    private var selectedDayTransactions: [Transaction] {
        guard let dc = selectedCalendarDate,
              let day = Calendar(identifier: .gregorian).date(from: dc) else { return [] }
        let cal = Calendar.current
        return data.transactions.filter { cal.isDate($0.dateValue, inSameDayAs: day) }
    }

    private var calendarCard: some View {
        DashCard {
            HStack {
                Text("Kalendarz wydatków").font(.headline)
                Spacer()
                if let total = selectedDayTotal, total > 0 {
                    Text("-\(total, format: .currency(code: "PLN"))")
                        .font(.subheadline.bold())
                        .foregroundStyle(.red)
                        .monospacedDigit()
                }
            }

            ExpenseCalendarView(
                dailyTotals: dailyExpenseTotals,
                selectedDate: $selectedCalendarDate
            )
            .frame(minHeight: 360)

            if let dc = selectedCalendarDate,
               let day = Calendar(identifier: .gregorian).date(from: dc) {
                Divider()
                Text(day, format: .dateTime.weekday(.wide).day().month(.wide))
                    .font(.subheadline.bold())
                if selectedDayTransactions.isEmpty {
                    Text("Brak transakcji tego dnia")
                        .font(.footnote).foregroundStyle(.secondary)
                } else {
                    VStack(spacing: 8) {
                        ForEach(selectedDayTransactions) { tx in
                            HStack {
                                Circle()
                                    .fill(Color(hex: data.category(id: tx.category_id)?.color ?? "#8E8E93").opacity(0.25))
                                    .frame(width: 28, height: 28)
                                    .overlay {
                                        Image(systemName: data.category(id: tx.category_id)?.icon ?? "circle.fill")
                                            .font(.caption)
                                            .foregroundStyle(Color(hex: data.category(id: tx.category_id)?.color ?? "#8E8E93"))
                                    }
                                Text(tx.description.isEmpty
                                     ? (data.category(id: tx.category_id)?.name ?? "—")
                                     : tx.description)
                                    .font(.footnote)
                                Spacer()
                                Text(tx.amount, format: .currency(code: "PLN"))
                                    .font(.footnote.monospacedDigit())
                                    .foregroundStyle(tx.amount < 0 ? .red : .green)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Charts

    enum ChartMode: String, CaseIterable, Identifiable {
        case daily, weekly, categories
        var id: String { rawValue }
        var label: String {
            switch self {
            case .daily: "Dni"
            case .weekly: "Tygodnie"
            case .categories: "Kategorie"
            }
        }
    }

    struct ChartBucket: Identifiable, Hashable {
        let id = UUID()
        let label: String
        let date: Date
        let amount: Double
    }
    struct CategoryBucket: Identifiable, Hashable {
        let id = UUID()
        let name: String
        let color: String
        let amount: Double
    }

    private var dailyBuckets: [ChartBucket] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        var dict: [Date: Double] = [:]
        for offset in (0...29).reversed() {
            if let d = cal.date(byAdding: .day, value: -offset, to: today) { dict[d] = 0 }
        }
        for tx in data.transactions where tx.amount < 0 {
            let day = cal.startOfDay(for: tx.dateValue)
            if dict[day] != nil { dict[day, default: 0] += abs(tx.amount) }
        }
        return dict
            .sorted { $0.key < $1.key }
            .map { ChartBucket(label: "", date: $0.key, amount: $0.value) }
    }

    private var weeklyBuckets: [ChartBucket] {
        let cal = Calendar.current
        guard let thisWeekStart = cal.dateInterval(of: .weekOfYear, for: Date())?.start else { return [] }
        var dict: [Date: Double] = [:]
        for offset in (0...11).reversed() {
            if let d = cal.date(byAdding: .weekOfYear, value: -offset, to: thisWeekStart) { dict[d] = 0 }
        }
        for tx in data.transactions where tx.amount < 0 {
            if let weekStart = cal.dateInterval(of: .weekOfYear, for: tx.dateValue)?.start,
               dict[weekStart] != nil {
                dict[weekStart, default: 0] += abs(tx.amount)
            }
        }
        return dict
            .sorted { $0.key < $1.key }
            .map { ChartBucket(label: "", date: $0.key, amount: $0.value) }
    }

    private var categoryBuckets: [CategoryBucket] {
        var dict: [UUID: Double] = [:]
        for tx in data.transactions where tx.amount < 0 {
            if let cid = tx.category_id {
                dict[cid, default: 0] += abs(tx.amount)
            }
        }
        return dict.compactMap { (cid, total) -> CategoryBucket? in
            guard let cat = data.category(id: cid) else { return nil }
            return CategoryBucket(name: cat.name, color: cat.color, amount: total)
        }
        .sorted { $0.amount > $1.amount }
    }

    private var chartsCard: some View {
        DashCard {
            HStack {
                Text("Analiza wydatków").font(.headline)
                Spacer()
            }
            Picker("Tryb", selection: $chartMode) {
                ForEach(ChartMode.allCases) { Text($0.label).tag($0) }
            }
            .pickerStyle(.segmented)

            switch chartMode {
            case .daily:     dailyChart
            case .weekly:    weeklyChart
            case .categories: categoriesChart
            }
        }
    }

    @ViewBuilder
    private var dailyChart: some View {
        let buckets = dailyBuckets
        if buckets.allSatisfy({ $0.amount == 0 }) {
            emptyChart(text: "Brak wydatków w ostatnich 30 dniach.")
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Text("Ostatnie 30 dni").font(.caption).foregroundStyle(.secondary)
                Chart(buckets) { b in
                    BarMark(
                        x: .value("Data", b.date, unit: .day),
                        y: .value("Kwota", b.amount)
                    )
                    .foregroundStyle(Color.red.gradient)
                    .cornerRadius(3)
                }
                .frame(height: 200)
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: 5)) { value in
                        AxisGridLine()
                        AxisValueLabel(format: .dateTime.day().month(.narrow))
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let v = value.as(Double.self) { Text(compactCurrency(v)) }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var weeklyChart: some View {
        let buckets = weeklyBuckets
        if buckets.allSatisfy({ $0.amount == 0 }) {
            emptyChart(text: "Brak wydatków w ostatnich 12 tygodniach.")
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Text("Ostatnie 12 tygodni").font(.caption).foregroundStyle(.secondary)
                Chart(buckets) { b in
                    BarMark(
                        x: .value("Tydzień", b.date, unit: .weekOfYear),
                        y: .value("Kwota", b.amount)
                    )
                    .foregroundStyle(Color.orange.gradient)
                    .cornerRadius(4)
                }
                .frame(height: 220)
                .chartXAxis {
                    AxisMarks(values: .stride(by: .weekOfYear)) { value in
                        AxisGridLine()
                        AxisValueLabel(format: .dateTime.day().month(.narrow))
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let v = value.as(Double.self) { Text(compactCurrency(v)) }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var categoriesChart: some View {
        let buckets = categoryBuckets
        let total = buckets.reduce(0) { $0 + $1.amount }
        if buckets.isEmpty {
            emptyChart(text: "Brak wydatków przypisanych do kategorii.")
        } else {
            VStack(spacing: 12) {
                Chart(buckets) { c in
                    SectorMark(
                        angle: .value("Kwota", c.amount),
                        innerRadius: .ratio(0.55),
                        angularInset: 1.5
                    )
                    .foregroundStyle(Color(hex: c.color))
                    .cornerRadius(2)
                }
                .frame(height: 220)
                .chartLegend(.hidden)

                VStack(spacing: 6) {
                    ForEach(buckets.prefix(6)) { c in
                        HStack {
                            Circle().fill(Color(hex: c.color)).frame(width: 10, height: 10)
                            Text(c.name).font(.footnote)
                            Spacer()
                            Text(c.amount, format: .currency(code: "PLN"))
                                .font(.footnote.monospacedDigit())
                            if total > 0 {
                                Text("\(Int((c.amount / total * 100).rounded()))%")
                                    .font(.caption2).foregroundStyle(.secondary)
                                    .frame(width: 36, alignment: .trailing)
                            }
                        }
                    }
                }
            }
        }
    }

    private func emptyChart(text: String) -> some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, minHeight: 160)
    }

    private func compactCurrency(_ v: Double) -> String {
        if v >= 1000 { return String(format: "%.0fk", v / 1000) }
        return String(format: "%.0f", v)
    }

    // MARK: - Upcoming bills

    private var upcomingBillsCard: some View {
        let upcoming = data.bills
            .filter { !$0.paid && $0.dueDateValue >= Calendar.current.startOfDay(for: Date()) }
            .prefix(5)

        return DashCard {
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
    }
}

// MARK: - Reusable card

private struct DashCard<Content: View>: View {
    var compact: Bool = false
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 4 : 12) {
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }
}
