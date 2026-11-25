//
//  Account.swift
//  iExpense
//
//  Bank accounts / cards model with cut and payment date logic.
//

import Foundation
import SwiftUI

enum AccountType: String, CaseIterable, Codable, Identifiable {
    case credit
    case debit

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .credit: return String(localized: "Credit")
        case .debit: return String(localized: "Debit")
        }
    }

    var iconName: String {
        switch self {
        case .credit: return "creditcard.fill"
        case .debit: return "banknote.fill"
        }
    }

    var tint: Color {
        switch self {
        case .credit: return .blue
        case .debit: return .green
        }
    }
}

struct Account: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var name: String
    var type: AccountType
    /// Maximum credit limit. Only meaningful for credit accounts.
    var creditLimit: Double = 0
    /// Starting balance. Only meaningful for debit accounts.
    var initialBalance: Double = 0
    /// Day of the month (1-31) when the statement cuts.
    var cutDay: Int = 1
    /// Days after the cut date until the payment is due.
    var graceDays: Int = 20
    var createdAt: Date = Date()

    init(
        id: UUID = UUID(),
        name: String,
        type: AccountType,
        creditLimit: Double = 0,
        initialBalance: Double = 0,
        cutDay: Int = 1,
        graceDays: Int = 20,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.creditLimit = creditLimit
        self.initialBalance = initialBalance
        self.cutDay = cutDay
        self.graceDays = graceDays
        self.createdAt = createdAt
    }

    // MARK: - Cut / payment dates

    /// Cut date of the cycle that starts `monthOffset` months from the
    /// month of `reference`. The day is clamped to the month's length
    /// (e.g. day 31 in February becomes day 28/29).
    private func cutDate(monthOffset: Int, from reference: Date, calendar: Calendar) -> Date {
        let base = calendar.date(byAdding: .month, value: monthOffset, to: reference) ?? reference
        let range = calendar.range(of: .day, in: .month, for: base) ?? 1..<32
        let day = min(max(cutDay, 1), range.count)
        var components = calendar.dateComponents([.year, .month], from: base)
        components.day = day
        return calendar.date(from: components) ?? reference
    }

    /// The most recent cut date on or before `date`.
    func lastCut(onOrBefore date: Date = Date(), calendar: Calendar = .current) -> Date {
        let thisMonth = cutDate(monthOffset: 0, from: date, calendar: calendar)
        if thisMonth <= date {
            return thisMonth
        }
        return cutDate(monthOffset: -1, from: date, calendar: calendar)
    }

    /// The next cut date after `date`.
    func nextCut(after date: Date = Date(), calendar: Calendar = .current) -> Date {
        let thisMonth = cutDate(monthOffset: 0, from: date, calendar: calendar)
        if thisMonth > date {
            return thisMonth
        }
        return cutDate(monthOffset: 1, from: date, calendar: calendar)
    }

    /// Payment due date: next cut date + grace days.
    func nextPaymentDate(after date: Date = Date(), calendar: Calendar = .current) -> Date {
        calendar.date(
            byAdding: .day,
            value: graceDays,
            to: nextCut(after: date, calendar: calendar)
        ) ?? nextCut(after: date, calendar: calendar)
    }

    /// Days remaining until the payment due date (0 = due today).
    func daysUntilPayment(from date: Date = Date(), calendar: Calendar = .current) -> Int {
        let due = nextPaymentDate(after: date, calendar: calendar)
        let startOfToday = calendar.startOfDay(for: date)
        let startOfDue = calendar.startOfDay(for: due)
        return calendar.dateComponents([.day], from: startOfToday, to: startOfDue).day ?? 0
    }

    // MARK: - Balances

    /// Net consumption from transactions recorded in the app during the current cycle
    /// (expenses minus payments registered as income between the last cut and the next one).
    func cycleTransactionsConsumed(expenses: [Expense], now: Date = Date(), calendar: Calendar = .current) -> Double {
        guard type == .credit else { return 0 }
        let start = lastCut(onOrBefore: now, calendar: calendar)
        let end = nextCut(after: now, calendar: calendar)
        let inCycle = expenses.filter {
            $0.accountID == id.uuidString && $0.date >= start && $0.date < end
        }
        let spent = inCycle.filter { $0.type == .expense }.reduce(0) { $0 + $1.price }
        let payments = inCycle.filter { $0.type == .income }.reduce(0) { $0 + $1.price }
        return spent - payments
    }

    /// Total credit consumption in the current cycle (manual/opening consumed balance
    /// plus net cycle transactions).
    func consumed(expenses: [Expense], now: Date = Date(), calendar: Calendar = .current) -> Double {
        guard type == .credit else { return 0 }
        let total = initialBalance + cycleTransactionsConsumed(expenses: expenses, now: now, calendar: calendar)
        return max(0, total)
    }

    /// Available balance (saldo libre) for credit accounts:
    /// credit limit minus consumption in the current cycle.
    func availableBalance(expenses: [Expense], now: Date = Date(), calendar: Calendar = .current) -> Double {
        creditLimit - consumed(expenses: expenses, now: now, calendar: calendar)
    }

    /// Current balance for debit accounts:
    /// initial balance plus income minus expenses registered to this account.
    func currentBalance(expenses: [Expense]) -> Double {
        guard type == .debit else { return 0 }
        let mine = expenses.filter { $0.accountID == id.uuidString }
        let income = mine.filter { $0.type == .income }.reduce(0) { $0 + $1.price }
        let spent = mine.filter { $0.type == .expense }.reduce(0) { $0 + $1.price }
        return initialBalance + income - spent
    }
}
