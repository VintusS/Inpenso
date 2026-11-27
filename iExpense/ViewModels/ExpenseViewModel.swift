//
//  ExpenseViewModel.swift
//  iExpense
//
//  Created by Dragomir Mindrescu on 27.04.2025.
//

import Foundation
import SwiftUI
import UIKit

@MainActor
class ExpenseViewModel: ObservableObject {
    @Published private(set) var expenses: [Expense] = []
    @Published private(set) var transferFeeIDs: Set<UUID> = []
    
    init() {
        loadExpenses()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationDidBecomeActive(_:)),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
    }
    
    func addExpense(
        title: String,
        price: Double,
        date: Date,
        category: Category,
        type: TransactionType = .expense,
        categoryID: String? = nil,
        notes: String? = nil,
        walletID: UUID? = nil
    ) throws -> Expense {
        var newExpense = Expense(
            title: title,
            price: price,
            date: date,
            category: category,
            type: type,
            categoryID: categoryID,
            notes: notes,
            walletID: walletID
        )
        defer { loadExpenses() }
        try StorageService.updateLedger { ledger in
            let id = walletID ?? ledger.defaultWalletID
            guard ledger.wallets.contains(where: { $0.id == id && !$0.isArchived })
            else { throw WalletError.unknownWallet }
            newExpense.walletID = id
            ledger.transactions.append(newExpense)
        }
        return newExpense
    }

    func deleteExpense(at offsets: IndexSet) {
        deleteExpenses(offsets.compactMap { expenses.indices.contains($0) ? expenses[$0] : nil })
    }

    @available(*, deprecated, message: "Use a transaction-specific mutation.")
    func saveExpenses() {
        loadExpenses()
    }

    @objc private func applicationDidBecomeActive(_ notification: Notification) {
        loadExpenses()
    }

    func loadExpenses() {
        let ledger = StorageService.loadLedger()
        expenses = ledger?.transactions ?? StorageService.loadExpenses()
        transferFeeIDs = Set(ledger?.transfers.compactMap(\.feeExpenseID) ?? [])
    }

    /// Fee rows are generated from their transfer on every write, so they are
    /// changed through the transfer, never directly.
    func isTransferFee(_ expense: Expense) -> Bool {
        transferFeeIDs.contains(expense.id)
    }

    func deleteExpenses(_ expenses: [Expense]) {
        let ids = Set(expenses.map(\.id)).subtracting(transferFeeIDs)
        changeExpenses { $0.removeAll { ids.contains($0.id) } }
    }

    func removeExpense(id: UUID) -> Expense? {
        guard !transferFeeIDs.contains(id) else { return nil }
        let removed = StorageService.updateExpenses { expenses -> Expense? in
            guard let index = expenses.firstIndex(where: { $0.id == id }) else { return nil }
            return expenses.remove(at: index)
        }
        loadExpenses()
        return expenses.contains(where: { $0.id == id }) ? nil : removed
    }

    func updateExpense(id: UUID, _ update: (inout Expense) -> Void) {
        guard !transferFeeIDs.contains(id) else { return }
        changeExpenses { expenses in
            guard let index = expenses.firstIndex(where: { $0.id == id }) else { return }
            update(&expenses[index])
        }
    }

    func restoreExpenses(_ deleted: [Expense]) {
        changeExpenses { expenses in
            var ids = Set(expenses.map(\.id))
            for expense in deleted where ids.insert(expense.id).inserted {
                expenses.append(expense)
            }
        }
    }

    private func changeExpenses(_ change: (inout [Expense]) -> Void) {
        StorageService.updateExpenses(change)
        loadExpenses()
    }
}
