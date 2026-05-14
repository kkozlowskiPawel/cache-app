import Foundation
import Supabase
import Combine

@MainActor
final class DataStore: ObservableObject {

    // MARK: - Published collections

    @Published var categories: [Category] = []
    @Published var accounts: [Account] = []
    @Published var transactions: [Transaction] = []
    @Published var subscriptions: [Subscription] = []
    @Published var bills: [Bill] = []
    @Published var budgets: [Budget] = []
    @Published var goals: [Goal] = []

    @Published var isLoading = false
    @Published var errorMessage: String?

    private let client = SupabaseService.client
    private var channels: [RealtimeChannelV2] = []

    // MARK: - Lifecycle

    func loadAll() async {
        isLoading = true; errorMessage = nil
        defer { isLoading = false }
        // Najpierw obciaz zalegle subskrypcje (idempotentne w bazie).
        _ = try? await client.rpc("charge_due_subscriptions").execute()
        do {
            async let cats: [Category] = client.from("categories").select().execute().value
            async let accs: [Account] = client.from("accounts").select().execute().value
            async let txs: [Transaction] = client.from("transactions").select().order("date", ascending: false).execute().value
            async let subs: [Subscription] = client.from("subscriptions").select().order("next_billing_date", ascending: true).execute().value
            async let bls: [Bill] = client.from("bills").select().order("due_date", ascending: true).execute().value
            async let buds: [Budget] = client.from("budgets").select().execute().value
            async let gls: [Goal] = client.from("goals").select().execute().value

            self.categories = try await cats
            self.accounts = try await accs
            self.transactions = try await txs
            self.subscriptions = try await subs
            self.bills = try await bls
            self.budgets = try await buds
            self.goals = try await gls
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func subscribeRealtime() async {
        await unsubscribeRealtime()
        let tables = ["categories", "accounts", "transactions", "subscriptions", "bills", "budgets", "goals"]
        for table in tables {
            let channel = client.channel("public:\(table)")
            let stream = channel.postgresChange(AnyAction.self, schema: "public", table: table)
            channels.append(channel)
            await channel.subscribe()
            Task { [weak self] in
                for await _ in stream {
                    await self?.refresh(table: table)
                }
            }
        }
    }

    func unsubscribeRealtime() async {
        for ch in channels { await ch.unsubscribe() }
        channels.removeAll()
    }

    private func refresh(table: String) async {
        do {
            switch table {
            case "categories":     categories = try await client.from(table).select().execute().value
            case "accounts":       accounts = try await client.from(table).select().execute().value
            case "transactions":   transactions = try await client.from(table).select().order("date", ascending: false).execute().value
            case "subscriptions":  subscriptions = try await client.from(table).select().order("next_billing_date", ascending: true).execute().value
            case "bills":          bills = try await client.from(table).select().order("due_date", ascending: true).execute().value
            case "budgets":        budgets = try await client.from(table).select().execute().value
            case "goals":          goals = try await client.from(table).select().execute().value
            default: break
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func clearLocal() {
        categories = []; accounts = []; transactions = []
        subscriptions = []; bills = []; budgets = []; goals = []
    }

    // MARK: - Current user

    private func currentUserId() async throws -> UUID {
        try await client.auth.session.user.id
    }

    // MARK: - Transactions

    func addTransaction(amount: Double, description: String, date: Date, categoryId: UUID?, accountId: UUID?) async {
        do {
            let row = TransactionInsert(
                user_id: try await currentUserId(),
                account_id: accountId,
                category_id: categoryId,
                amount: amount,
                description: description,
                date: DateOnly.string(from: date)
            )
            try await client.from("transactions").insert(row).execute()
        } catch { errorMessage = error.localizedDescription }
    }

    func deleteTransaction(_ tx: Transaction) async {
        do { try await client.from("transactions").delete().eq("id", value: tx.id).execute() }
        catch { errorMessage = error.localizedDescription }
    }

    // MARK: - Subscriptions

    func addSubscription(
        name: String,
        amount: Double,
        cycle: BillingCycle,
        nextDate: Date,
        categoryId: UUID?,
        accountId: UUID?,
        notes: String?,
        type: CategoryType = .expense,
        firstPaymentDate: Date? = nil
    ) async {
        do {
            let userId = try await currentUserId()
            let row = SubscriptionInsert(
                user_id: userId,
                name: name,
                amount: amount,
                billing_cycle: cycle,
                next_billing_date: DateOnly.string(from: nextDate),
                category_id: categoryId,
                account_id: accountId,
                notes: notes,
                type: type
            )
            try await client.from("subscriptions").insert(row).execute()

            if let firstDate = firstPaymentDate {
                let signed = type == .income ? amount : -amount
                let desc = type == .income ? "Przychód: \(name)" : "Subskrypcja: \(name)"
                let tx = TransactionInsert(
                    user_id: userId,
                    account_id: accountId,
                    category_id: categoryId,
                    amount: signed,
                    description: desc,
                    date: DateOnly.string(from: firstDate),
                    is_recurring: true
                )
                try await client.from("transactions").insert(tx).execute()
            }
        } catch { errorMessage = error.localizedDescription }
    }

    func updateTransaction(_ tx: Transaction, amount: Double, description: String, date: Date, categoryId: UUID?, accountId: UUID?) async {
        do {
            let payload = TransactionUpdate(
                account_id: accountId,
                category_id: categoryId,
                amount: amount,
                description: description,
                date: DateOnly.string(from: date)
            )
            try await client.from("transactions")
                .update(payload)
                .eq("id", value: tx.id)
                .execute()
        } catch { errorMessage = error.localizedDescription }
    }

    func toggleSubscriptionActive(_ sub: Subscription) async {
        do {
            try await client.from("subscriptions")
                .update(["active": !sub.active])
                .eq("id", value: sub.id)
                .execute()
        } catch { errorMessage = error.localizedDescription }
    }

    func deleteSubscription(_ sub: Subscription) async {
        do { try await client.from("subscriptions").delete().eq("id", value: sub.id).execute() }
        catch { errorMessage = error.localizedDescription }
    }

    // MARK: - Bills

    func addBill(name: String, amount: Double, dueDate: Date, categoryId: UUID?, reminderDays: Int) async {
        do {
            let row = BillInsert(
                user_id: try await currentUserId(),
                name: name,
                amount: amount,
                due_date: DateOnly.string(from: dueDate),
                category_id: categoryId,
                reminder_days_before: reminderDays
            )
            try await client.from("bills").insert(row).execute()
            await NotificationService.shared.scheduleBillReminder(name: name, amount: amount, dueDate: dueDate, daysBefore: reminderDays)
        } catch { errorMessage = error.localizedDescription }
    }

    func togglePaid(_ bill: Bill) async {
        do {
            try await client.from("bills")
                .update(["paid": !bill.paid])
                .eq("id", value: bill.id)
                .execute()
        } catch { errorMessage = error.localizedDescription }
    }

    func deleteBill(_ bill: Bill) async {
        do { try await client.from("bills").delete().eq("id", value: bill.id).execute() }
        catch { errorMessage = error.localizedDescription }
    }

    // MARK: - Budgets

    func setBudget(categoryId: UUID, amount: Double, period: BudgetPeriod) async {
        do {
            let row = BudgetInsert(
                user_id: try await currentUserId(),
                category_id: categoryId,
                amount: amount,
                period: period,
                start_date: DateOnly.string(from: Date())
            )
            try await client.from("budgets")
                .upsert(row, onConflict: "user_id,category_id,period")
                .execute()
        } catch { errorMessage = error.localizedDescription }
    }

    func deleteBudget(_ budget: Budget) async {
        do { try await client.from("budgets").delete().eq("id", value: budget.id).execute() }
        catch { errorMessage = error.localizedDescription }
    }

    // MARK: - Goals

    func addGoal(name: String, target: Double, current: Double, targetDate: Date?, icon: String, color: String) async {
        do {
            let row = GoalInsert(
                user_id: try await currentUserId(),
                name: name,
                target_amount: target,
                current_amount: current,
                target_date: targetDate.map { DateOnly.string(from: $0) },
                icon: icon,
                color: color
            )
            try await client.from("goals").insert(row).execute()
        } catch { errorMessage = error.localizedDescription }
    }

    func updateGoalCurrent(_ goal: Goal, current: Double) async {
        do {
            try await client.from("goals")
                .update(["current_amount": current])
                .eq("id", value: goal.id)
                .execute()
        } catch { errorMessage = error.localizedDescription }
    }

    func deleteGoal(_ goal: Goal) async {
        do { try await client.from("goals").delete().eq("id", value: goal.id).execute() }
        catch { errorMessage = error.localizedDescription }
    }

    // MARK: - Accounts

    func addAccount(name: String, type: AccountType, balance: Double) async {
        do {
            let row = AccountInsert(
                user_id: try await currentUserId(),
                name: name,
                type: type,
                balance: balance
            )
            try await client.from("accounts").insert(row).execute()
        } catch { errorMessage = error.localizedDescription }
    }

    func deleteAccount(_ acc: Account) async {
        do { try await client.from("accounts").delete().eq("id", value: acc.id).execute() }
        catch { errorMessage = error.localizedDescription }
    }

    // MARK: - Aggregations / helpers

    func category(id: UUID?) -> Category? {
        guard let id else { return nil }
        return categories.first { $0.id == id }
    }

    func account(id: UUID?) -> Account? {
        guard let id else { return nil }
        return accounts.first { $0.id == id }
    }

    /// Suma wydatków w bieżącym miesiącu w kategorii.
    func currentMonthExpense(categoryId: UUID) -> Double {
        let cal = Calendar.current
        let now = Date()
        return transactions
            .filter { $0.category_id == categoryId && $0.amount < 0 }
            .filter { cal.isDate($0.dateValue, equalTo: now, toGranularity: .month) }
            .reduce(0) { $0 + abs($1.amount) }
    }

    var monthlySubscriptionsTotal: Double {
        subscriptions.filter(\.active).reduce(0) { $0 + $1.monthlyEquivalent }
    }

    var monthlyExpenses: Double {
        let cal = Calendar.current; let now = Date()
        return transactions
            .filter { $0.amount < 0 }
            .filter { cal.isDate($0.dateValue, equalTo: now, toGranularity: .month) }
            .reduce(0) { $0 + abs($1.amount) }
    }

    var monthlyIncome: Double {
        let cal = Calendar.current; let now = Date()
        return transactions
            .filter { $0.amount > 0 }
            .filter { cal.isDate($0.dateValue, equalTo: now, toGranularity: .month) }
            .reduce(0) { $0 + $1.amount }
    }

    var netWorth: Double {
        accounts.reduce(0) { $0 + $1.balance }
    }
}
