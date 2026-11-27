// AddQuickExpenseIntent.swift
// iExpenseWidgetExtension

import AppIntents
import Foundation

struct AddQuickExpenseIntent: AppIntent {
    static var title: LocalizedStringResource = "Add Quick Expense"

    @Parameter(title: "Title")
    var title: String

    @Parameter(title: "Price")
    var price: Double

    @Parameter(title: "Category")
    var category: String

    init() {}

    init(title: String, price: Double, category: String) {
        self.title = title
        self.price = price
        self.category = category
    }

    func perform() async throws -> some IntentResult {
        var newExpense = Expense(
            title: title,
            price: price,
            date: Date(),
            category: Category(rawValue: category) ?? .others
        )
        try StorageService.updateLedger { ledger in
            newExpense.walletID = ledger.defaultWalletID
            ledger.transactions.append(newExpense)
        }
        
        return .result()
    }
}
