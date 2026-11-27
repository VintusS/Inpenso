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
    // swiftlint:disable:next large_tuple
    typealias InstalmentOptions = (months: Int, monthlyFee: Double, payFromWalletID: UUID?)

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
        walletID: UUID? = nil,
        refundOfID: UUID? = nil
    ) throws -> Expense {
        try recordExpense(Expense(
            title: title,
            price: price,
            date: date,
            category: category,
            type: type,
            categoryID: categoryID,
            notes: notes,
            walletID: walletID,
            refundOfID: type == .refund ? refundOfID : nil
        ))
    }

    func addCreditPurchase(
        _ expense: Expense,
        instalment: InstalmentOptions?
    ) throws {
        _ = try recordExpense(expense, requiresCredit: true, instalment: instalment)
        NotificationCenter.default.post(name: .inpensoDataDidChange, object: nil)
    }

    func payInstalment(_ plan: InstalmentPlan, amount: Double, from walletID: UUID, date: Date) throws {
        defer { loadExpenses() }
        try WalletService.payInstalment(plan, amount: amount, from: walletID, date: date)
    }

    private func recordExpense(
        _ expense: Expense,
        requiresCredit: Bool = false,
        instalment: InstalmentOptions? = nil
    ) throws -> Expense {
        var newExpense = expense
        defer { loadExpenses() }
        try StorageService.updateLedger { ledger in
            let id = expense.walletID ?? ledger.defaultWalletID
            guard let wallet = ledger.wallets.first(where: { $0.id == id && !$0.isArchived }),
                  !requiresCredit || wallet.kind.isCredit
            else { throw WalletError.unknownWallet }
            if requiresCredit {
                guard expense.type == .expense, expense.price.isFinite, expense.price > 0,
                      wallet.openingDate.map({ $0 <= expense.date }) ?? true
                else { throw WalletError.invalidAmount }
                if ledger.transactions.contains(where: { $0.id == expense.id }) { return }
            }
            newExpense.walletID = id
            ledger.transactions.append(newExpense)
            if let instalment {
                guard instalment.months >= 1 else { throw WalletError.invalidAmount }
                let calendar = Calendar.current
                guard let nextMonth = calendar.date(byAdding: .month, value: 1, to: expense.date)
                else { throw WalletError.invalidAmount }
                let firstDueDate = wallet.dueDay.flatMap { creditDate(day: $0, inMonthOf: nextMonth) } ?? nextMonth
                let plan = InstalmentPlan(
                    purchaseExpenseID: expense.id, creditWalletID: id, payFromWalletID: instalment.payFromWalletID,
                    principal: expense.price, months: instalment.months,
                    monthlyAmount: expense.price / Double(instalment.months), monthlyFee: instalment.monthlyFee,
                    firstDueDate: firstDueDate, title: expense.title,
                    scheduledDay: wallet.dueDay ?? calendar.component(.day, from: expense.date)
                )
                if ledger.instalmentPlans == nil { ledger.instalmentPlans = [] }
                ledger.instalmentPlans?.append(plan)
            }
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
