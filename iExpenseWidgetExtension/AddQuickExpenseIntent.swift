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
        var expenses = StorageService.loadExpenses()
        let newExpense = Expense(
            title: title,
            price: price,
            date: Date(),
            category: Category(rawValue: category) ?? .others
        )
        expenses.append(newExpense)
        StorageService.saveExpenses(expenses)
        
        return .result()
    }
}
