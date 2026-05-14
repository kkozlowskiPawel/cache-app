import SwiftUI
import Charts

struct HomeView: View {
    @EnvironmentObject var data: DataStore

    @State private var selectedCalendarDate: DateComponents? = nil
    @State private var chartMode: ChartMode = .daily
    @State private var selectedAccountId: UUID? = nil   // nil = wszystkie

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    accountCarousel
                    monthSummary
                    calendarCard
                    chartsCard
                    upcomingBillsCard
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Dashboard")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            withAnimation { selectedAccountId = nil }
                        } label: {
                            Label("Wszystkie konta", systemImage: selectedAccountId == nil ? "checkmark" : "")
                        }
                        Divider()
                        ForEach(data.accounts) { a in
                            Button {
                                withAnimation { selectedAccountId = a.id }
                            } label: {
                                Label(a.name, systemImage: selectedAccountId == a.id ? "checkmark" : "")
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(selectedAccountLabel)
                                .font(.subheadline.weight(.medium))
                            Image(systemName: "chevron.down")
                                .font(.caption2.weight(.semibold))
                        }
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color(.secondarySystemBackground), in: Capsule())
                    }
                }
            }
            .refreshable { await data.loadAll() }
        }
    }

    // MARK: - Filtering

    private var filteredTransactions: [Transaction] {
        guard let aid = selectedAccountId else { return data.transactions }
        return data.transactions.filter { $0.account_id == aid }
    }

    private var selectedAccount: Account? {
        guard let aid = selectedAccountId else { return nil }
        return data.accounts.first { $0.id == aid }
    }

    private var selectedAccountLabel: String {
        selectedAccount?.name ?? "Wszystkie"
    }

    private var monthlyIncome: Double {
        let cal = Calendar.current; let now = Date()
        return filteredTransactions
            .filter { $0.amount > 0 && cal.isDate($0.dateValue, equalTo: now, toGranularity: .month) }
            .reduce(0) { $0 + $1.amount }
    }
    private var monthlyExpenses: Double {
        let cal = Calendar.current; let now = Date()
        return filteredTransactions
            .filter { $0.amount < 0 && cal.isDate($0.dateValue, equalTo: now, toGranularity: .month) }
            .reduce(0) { $0 + abs($1.amount) }
    }
    private var savings: Double { monthlyIncome - monthlyExpenses }

    // MARK: - Account carousel

    private struct AccountSummary: Identifiable {
        let id: String   // "all" or UUID.uuidString
        let title: String
        let subtitle: String
        let balance: Double
        let income: Double
        let expense: Double
        let systemIcon: String
    }

    private var accountSummaries: [AccountSummary] {
        let cal = Calendar.current; let now = Date()

        // Per-account monthly aggregates from ALL transactions (carousel pokazuje wszystko)
        var perAcc: [UUID: (inc: Double, exp: Double)] = [:]
        for tx in data.transactions {
            guard let aid = tx.account_id,
                  cal.isDate(tx.dateValue, equalTo: now, toGranularity: .month) else { continue }
            var cur = perAcc[aid] ?? (0, 0)
            if tx.amount > 0 { cur.inc += tx.amount } else { cur.exp += abs(tx.amount) }
            perAcc[aid] = cur
        }
        let totalInc = perAcc.values.reduce(0) { $0 + $1.inc }
        let totalExp = perAcc.values.reduce(0) { $0 + $1.exp }

        var out: [AccountSummary] = [
            AccountSummary(
                id: "all",
                title: "Wartość netto",
                subtitle: "\(data.accounts.count) kont",
                balance: data.netWorth,
                income: totalInc,
                expense: totalExp,
                systemIcon: "creditcard.fill"
            )
        ]
        for a in data.accounts {
            let agg = perAcc[a.id] ?? (0, 0)
            out.append(AccountSummary(
                id: a.id.uuidString,
                title: a.name,
                subtitle: a.type.label,
                balance: a.balance,
                income: agg.inc,
                expense: agg.exp,
                systemIcon: iconForAccountType(a.type)
            ))
        }
        return out
    }

    private func iconForAccountType(_ t: AccountType) -> String {
        switch t {
        case .cash: "banknote.fill"
        case .checking: "building.columns.fill"
        case .savings: "wallet.pass.fill"
        case .credit_card: "creditcard.fill"
        case .investment: "chart.line.uptrend.xyaxis"
        case .loan: "doc.text.fill"
        }
    }

    private var accountCarousel: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(accountSummaries) { s in
                    let isSelected = (s.id == "all" && selectedAccountId == nil)
                        || (selectedAccountId?.uuidString == s.id)
                    Button {
                        withAnimation {
                            selectedAccountId = (s.id == "all") ? nil : UUID(uuidString: s.id)
                        }
                    } label: {
                        accountCard(s, selected: isSelected)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 2)
        }
        .scrollClipDisabled()
    }

    private func accountCard(_ s: AccountSummary, selected: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: s.systemIcon)
                    .font(.callout)
                    .foregroundStyle(selected ? .white : .accentColor)
                    .frame(width: 28, height: 28)
                    .background(
                        Circle().fill(selected ? Color.white.opacity(0.2) : Color.accentColor.opacity(0.15))
                    )
                VStack(alignment: .leading, spacing: 0) {
                    Text(s.title)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    Text(s.subtitle)
                        .font(.caption2)
                        .foregroundStyle(selected ? .white.opacity(0.75) : .secondary)
                        .lineLimit(1)
                }
            }
            Text(s.balance, format: .currency(code: "PLN"))
                .font(.title3.bold().monospacedDigit())
                .lineLimit(1).minimumScaleFactor(0.7)
            HStack {
                Text("+\(s.income, format: .currency(code: "PLN"))")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(selected ? .white.opacity(0.9) : .green)
                Spacer()
                Text("-\(s.expense, format: .currency(code: "PLN"))")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(selected ? .white.opacity(0.9) : .red)
            }
        }
        .padding(14)
        .frame(width: 220, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(selected ? Color.accentColor : Color(.secondarySystemGroupedBackground))
        )
        .foregroundStyle(selected ? .white : .primary)
        .shadow(color: selected ? .accentColor.opacity(0.25) : .clear, radius: 8, y: 3)
    }

    // MARK: - Month summary

    private var monthSummary: some View {
        DashCard {
            HStack(alignment: .firstTextBaseline) {
                Text("Ten miesiąc").font(.headline)
                if selectedAccount != nil {
                    Text("· \(selectedAccountLabel)")
                        .font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer()
                Text(Date(), format: .dateTime.month(.wide).year())
                    .font(.footnote).foregroundStyle(.secondary)
            }
            HStack(spacing: 12) {
                statTile(title: "Przychód",  value: monthlyIncome,   color: .green,  icon: "arrow.down.circle.fill")
                statTile(title: "Wydatki",   value: monthlyExpenses, color: .red,    icon: "arrow.up.circle.fill")
                statTile(title: "Oszczędn.", value: savings,         color: savings >= 0 ? .blue : .orange, icon: "banknote.fill")
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

    // MARK: - Calendar

    private var dailyExpenseTotals: [DateComponents: Double] {
        let cal = Calendar(identifier: .gregorian)
        var dict: [DateComponents: Double] = [:]
        for tx in filteredTransactions where tx.amount < 0 {
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
        return filteredTransactions.filter { cal.isDate($0.dateValue, inSameDayAs: day) }
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
        for tx in filteredTransactions where tx.amount < 0 {
            let day = cal.startOfDay(for: tx.dateValue)
            if dict[day] != nil { dict[day, default: 0] += abs(tx.amount) }
        }
        return dict.sorted { $0.key < $1.key }.map { ChartBucket(label: "", date: $0.key, amount: $0.value) }
    }

    private var weeklyBuckets: [ChartBucket] {
        let cal = Calendar.current
        guard let thisWeekStart = cal.dateInterval(of: .weekOfYear, for: Date())?.start else { return [] }
        var dict: [Date: Double] = [:]
        for offset in (0...11).reversed() {
            if let d = cal.date(byAdding: .weekOfYear, value: -offset, to: thisWeekStart) { dict[d] = 0 }
        }
        for tx in filteredTransactions where tx.amount < 0 {
            if let ws = cal.dateInterval(of: .weekOfYear, for: tx.dateValue)?.start, dict[ws] != nil {
                dict[ws, default: 0] += abs(tx.amount)
            }
        }
        return dict.sorted { $0.key < $1.key }.map { ChartBucket(label: "", date: $0.key, amount: $0.value) }
    }

    private var categoryBuckets: [CategoryBucket] {
        var dict: [UUID: Double] = [:]
        for tx in filteredTransactions where tx.amount < 0 {
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
            case .daily:      dailyChart
            case .weekly:     weeklyChart
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
                    AxisMarks(values: .stride(by: .day, count: 5)) { _ in
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
                    AxisMarks(values: .stride(by: .weekOfYear)) { _ in
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
            .filter { selectedAccountId == nil ? true : $0.account_id == selectedAccountId }
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
