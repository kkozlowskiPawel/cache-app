import Foundation

// MARK: - Enums

enum CategoryType: String, Codable, CaseIterable, Identifiable {
    case income, expense
    var id: String { rawValue }
    var label: String { self == .income ? "Przychód" : "Wydatek" }
}

enum AccountType: String, Codable, CaseIterable, Identifiable {
    case cash, checking, savings, credit_card, investment, loan
    var id: String { rawValue }
    var label: String {
        switch self {
        case .cash: "Gotówka"
        case .checking: "Konto bieżące"
        case .savings: "Oszczędności"
        case .credit_card: "Karta kredytowa"
        case .investment: "Inwestycje"
        case .loan: "Pożyczka"
        }
    }
}

enum BillingCycle: String, Codable, CaseIterable, Identifiable {
    case weekly, monthly, quarterly, yearly
    var id: String { rawValue }
    var label: String {
        switch self {
        case .weekly: "Tygodniowo"
        case .monthly: "Miesięcznie"
        case .quarterly: "Kwartalnie"
        case .yearly: "Rocznie"
        }
    }
    /// Multiplier to convert one billing period into a monthly equivalent.
    var monthlyFactor: Double {
        switch self {
        case .weekly: 52.0 / 12.0
        case .monthly: 1
        case .quarterly: 1.0 / 3.0
        case .yearly: 1.0 / 12.0
        }
    }
}

enum BudgetPeriod: String, Codable, CaseIterable, Identifiable {
    case weekly, monthly, yearly
    var id: String { rawValue }
    var label: String {
        switch self {
        case .weekly: "Tygodniowy"
        case .monthly: "Miesięczny"
        case .yearly: "Roczny"
        }
    }
}

// MARK: - Date helper (Postgres "date" columns come as "YYYY-MM-DD")

enum DateOnly {
    static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .iso8601)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(secondsFromGMT: 0)
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static func string(from date: Date) -> String { formatter.string(from: date) }
    static func date(from string: String) -> Date { formatter.date(from: string) ?? Date() }
}

// MARK: - Models

struct Category: Identifiable, Codable, Hashable {
    var id: UUID
    var user_id: UUID
    var name: String
    var icon: String
    var color: String
    var type: CategoryType
}

struct Account: Identifiable, Codable, Hashable {
    var id: UUID
    var user_id: UUID
    var name: String
    var type: AccountType
    var balance: Double
    var currency: String
    var icon: String
}

struct Transaction: Identifiable, Codable, Hashable {
    var id: UUID
    var user_id: UUID
    var account_id: UUID?
    var category_id: UUID?
    var amount: Double
    var description: String
    var date: String      // "YYYY-MM-DD"
    var is_recurring: Bool

    var dateValue: Date { DateOnly.date(from: date) }
}

struct Subscription: Identifiable, Codable, Hashable {
    var id: UUID
    var user_id: UUID
    var name: String
    var amount: Double
    var billing_cycle: BillingCycle
    var next_billing_date: String
    var category_id: UUID?
    var account_id: UUID?
    var icon: String
    var color: String
    var active: Bool
    var notes: String?
    var type: CategoryType

    var nextBillingDateValue: Date { DateOnly.date(from: next_billing_date) }
    var monthlyEquivalent: Double { amount * billing_cycle.monthlyFactor }
}

struct Bill: Identifiable, Codable, Hashable {
    var id: UUID
    var user_id: UUID
    var name: String
    var amount: Double
    var due_date: String
    var paid: Bool
    var category_id: UUID?
    var account_id: UUID?
    var reminder_days_before: Int

    var dueDateValue: Date { DateOnly.date(from: due_date) }
}

struct Budget: Identifiable, Codable, Hashable {
    var id: UUID
    var user_id: UUID
    var category_id: UUID
    var amount: Double
    var period: BudgetPeriod
    var start_date: String
}

struct Goal: Identifiable, Codable, Hashable {
    var id: UUID
    var user_id: UUID
    var name: String
    var target_amount: Double
    var current_amount: Double
    var target_date: String?
    var icon: String
    var color: String

    var progress: Double {
        guard target_amount > 0 else { return 0 }
        return min(current_amount / target_amount, 1.0)
    }
}

// MARK: - Inserts (no id / user_id — auto-set by DB / DataStore)

struct TransactionInsert: Encodable {
    var user_id: UUID
    var account_id: UUID?
    var category_id: UUID?
    var amount: Double
    var description: String
    var date: String
    var is_recurring: Bool = false
}

struct SubscriptionInsert: Encodable {
    var user_id: UUID
    var name: String
    var amount: Double
    var billing_cycle: BillingCycle
    var next_billing_date: String
    var category_id: UUID?
    var account_id: UUID?
    var icon: String = "repeat"
    var color: String = "#34C759"
    var active: Bool = true
    var notes: String?
    var type: CategoryType = .expense
}

struct TransactionUpdate: Encodable {
    var account_id: UUID?
    var category_id: UUID?
    var amount: Double
    var description: String
    var date: String
}

struct BillInsert: Encodable {
    var user_id: UUID
    var name: String
    var amount: Double
    var due_date: String
    var paid: Bool = false
    var category_id: UUID?
    var account_id: UUID?
    var reminder_days_before: Int = 3
}

struct PayBillParams: Encodable {
    var bill_id: UUID
}

struct BudgetInsert: Encodable {
    var user_id: UUID
    var category_id: UUID
    var amount: Double
    var period: BudgetPeriod
    var start_date: String
}

struct GoalInsert: Encodable {
    var user_id: UUID
    var name: String
    var target_amount: Double
    var current_amount: Double = 0
    var target_date: String?
    var icon: String = "target"
    var color: String = "#007AFF"
}

struct AccountInsert: Encodable {
    var user_id: UUID
    var name: String
    var type: AccountType
    var balance: Double
    var currency: String = "PLN"
    var icon: String = "creditcard.fill"
}

// MARK: - Color helper

import SwiftUI

extension Color {
    init(hex: String) {
        let s = hex.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "#", with: "")
        var v: UInt64 = 0
        Scanner(string: s).scanHexInt64(&v)
        let r = Double((v & 0xFF0000) >> 16) / 255
        let g = Double((v & 0x00FF00) >> 8) / 255
        let b = Double(v & 0x0000FF) / 255
        self.init(red: r, green: g, blue: b)
    }
}
