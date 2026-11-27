//
//  Wallet.swift
//  iExpense
//

import Foundation
import SwiftUI

enum WalletKind: String, Codable, CaseIterable, Identifiable {
    case cash
    case bank
    case eWallet
    case credit
    case other

    var id: String { rawValue }
    var isCredit: Bool { self == .credit }

    var displayName: String {
        switch self {
        case .cash:
            return "Cash"
        case .bank:
            return "Bank"
        case .eWallet:
            return "E-Wallet"
        case .credit:
            return "Credit"
        case .other:
            return "Other"
        }
    }

    var defaultIconName: String {
        switch self {
        case .cash:
            return "banknote.fill"
        case .bank:
            return "building.columns.fill"
        case .eWallet:
            return "iphone.gen3"
        case .credit:
            return "creditcard.fill"
        case .other:
            return "wallet.pass.fill"
        }
    }
}

/// A place money lives: cash, a bank account or an e-wallet.
/// Balance is never stored; it is computed from the opening balance and the ledger.
struct Wallet: Identifiable, Codable, Equatable, Hashable {
    var id: UUID = UUID()
    var name: String
    var kind: WalletKind
    var iconName: String
    var colorHex: String
    /// Balance immediately before any activity on `openingDate`.
    var openingBalance: Double = 0
    /// nil = unbounded (migrated wallets: every past transaction counts).
    var openingDate: Date?
    var isArchived: Bool = false
    var sortOrder: Int = 0
    var creditLimit: Double?
    var statementDay: Int?
    var dueDay: Int?

    var color: Color { Color(hex: colorHex) ?? .accentColor }
}

/// Money moved between two of the user's wallets. Never counts as income or spending.
/// An optional fee is posted as a linked expense (`feeExpenseID`) in the same write.
struct Transfer: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var fromWalletID: UUID
    var toWalletID: UUID
    /// Positive amount that arrives in the destination wallet.
    var amount: Double
    var date: Date
    var note: String?
    /// Fee charged to the source wallet, recorded as an expense; nil or 0 = no fee.
    var feeAmount: Double?
    var feeExpenseID: UUID?
    var instalmentPlanID: UUID?
}

struct InstalmentPlan: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var purchaseExpenseID: UUID?
    var creditWalletID: UUID
    var payFromWalletID: UUID?
    var principal: Double
    var months: Int
    var monthlyAmount: Double
    var monthlyFee: Double
    var firstDueDate: Date
    var title: String
    var scheduledDay: Int?

    func dueDate(at index: Int, calendar: Calendar = .current) -> Date? {
        guard index >= 0, index < months,
              let date = calendar.date(byAdding: .month, value: index, to: firstDueDate)
        else { return nil }
        return scheduledDay.flatMap { creditDate(day: $0, inMonthOf: date, calendar: calendar) } ?? date
    }
}

struct InstalmentProgress {
    let paidCount: Int
    let remainingPrincipal: Double
    let nextDueDate: Date?
    let isFinished: Bool
}

struct DueItem: Identifiable {
    enum Kind { case instalment(UUID), cardDue(UUID) }

    let id: String
    let kind: Kind
    let walletID: UUID
    let title: String
    let amount: Double
    let dueDate: Date
}

enum WalletError: LocalizedError {
    case sameWallet
    case invalidAmount
    case unknownWallet
    case lastActiveWallet
    case storageFailure

    var errorDescription: String? {
        switch self {
        case .sameWallet:
            return "Choose two different wallets."
        case .invalidAmount:
            return "Enter an amount above zero."
        case .unknownWallet:
            return "That wallet no longer exists."
        case .lastActiveWallet:
            return "Keep at least one active wallet."
        case .storageFailure:
            return "Couldn't save. Try again."
        }
    }
}

func creditDate(day: Int, inMonthOf date: Date, calendar: Calendar = .current) -> Date? {
    guard (1...31).contains(day),
          let month = calendar.dateInterval(of: .month, for: date),
          let days = calendar.range(of: .day, in: .month, for: date)
    else { return nil }
    return calendar.date(byAdding: .day, value: min(day, days.count) - 1, to: month.start)
}
