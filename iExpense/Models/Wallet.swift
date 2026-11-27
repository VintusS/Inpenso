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
    case other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .cash:
            return "Cash"
        case .bank:
            return "Bank"
        case .eWallet:
            return "E-Wallet"
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
