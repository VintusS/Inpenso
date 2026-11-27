//
//  WalletsViewModel.swift
//  iExpense
//

import Foundation

/// One line in a wallet's history: a transaction or one side of a transfer.
struct WalletActivity: Identifiable {
    enum Kind {
        case transaction(Expense)
        case transferOut(Transfer, to: Wallet?)
        case transferIn(Transfer, from: Wallet?)
    }

    let kind: Kind

    var id: String {
        switch kind {
        case .transaction(let expense): return "tx-\(expense.id)"
        case .transferOut(let transfer, _): return "out-\(transfer.id)"
        case .transferIn(let transfer, _): return "in-\(transfer.id)"
        }
    }

    var date: Date {
        switch kind {
        case .transaction(let expense): return expense.date
        case .transferOut(let transfer, _), .transferIn(let transfer, _): return transfer.date
        }
    }

    /// Signed effect on this wallet's balance.
    var signedAmount: Double {
        switch kind {
        case .transaction(let expense): return expense.type == .income ? expense.price : -expense.price
        case .transferOut(let transfer, _): return -transfer.amount
        case .transferIn(let transfer, _): return transfer.amount
        }
    }
}

@MainActor
final class WalletsViewModel: ObservableObject {
    @Published private(set) var wallets: [Wallet] = []
    @Published private(set) var balances: [UUID: Double] = [:]
    @Published private(set) var transfers: [Transfer] = []
    @Published private(set) var defaultWalletID: UUID?

    init() {
        refresh()
    }

    var activeWallets: [Wallet] { wallets.filter { !$0.isArchived } }
    var archivedWallets: [Wallet] { wallets.filter(\.isArchived) }

    /// Sum over all wallets, archived included, so money in an archived wallet is not lost from view.
    var totalBalance: Double { wallets.reduce(0) { $0 + (balances[$1.id] ?? 0) } }

    func wallet(for id: UUID?) -> Wallet? {
        guard let id else { return nil }
        return wallets.first { $0.id == id }
    }

    func balance(of wallet: Wallet) -> Double { balances[wallet.id] ?? wallet.openingBalance }

    func refresh() {
        wallets = WalletService.loadWallets()
        balances = WalletService.balances(asOf: Date())
        transfers = WalletService.loadTransfers()
        defaultWalletID = WalletService.defaultWalletID()
    }

    /// Newest first.
    func activity(for wallet: Wallet, expenses: [Expense]) -> [WalletActivity] {
        var items = expenses
            .filter { $0.walletID == wallet.id }
            .map { WalletActivity(kind: .transaction($0)) }
        for transfer in transfers {
            if transfer.fromWalletID == wallet.id {
                items.append(WalletActivity(kind: .transferOut(transfer, to: self.wallet(for: transfer.toWalletID))))
            }
            if transfer.toWalletID == wallet.id {
                items.append(WalletActivity(kind: .transferIn(transfer, from: self.wallet(for: transfer.fromWalletID))))
            }
        }
        return items.sorted { $0.date > $1.date }
    }

    func isFee(_ expense: Expense) -> Bool {
        transfers.contains { $0.feeExpenseID == expense.id }
    }

    // MARK: Actions (errors surface to the caller for an alert)

    func save(_ wallet: Wallet) throws {
        try WalletService.saveWallet(wallet)
        refresh()
    }

    func archive(_ wallet: Wallet) throws {
        let replacement = activeWallets.first { $0.id != wallet.id }?.id
        try WalletService.archiveWallet(wallet.id, replacementDefault: replacement)
        refresh()
    }

    func unarchive(_ wallet: Wallet) throws {
        try WalletService.unarchiveWallet(wallet.id)
        refresh()
    }

    func makeDefault(_ wallet: Wallet) throws {
        try WalletService.setDefaultWallet(wallet.id)
        refresh()
    }

    func save(_ transfer: Transfer) throws {
        try WalletService.saveTransfer(transfer)
        refresh()
    }

    func delete(_ transfer: Transfer) throws {
        try WalletService.deleteTransfer(transfer.id)
        refresh()
    }
}
