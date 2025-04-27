//
//  AddExpenseSiriIntent.swift
//  iExpense
//
//  Created by Dragomir Mindrescu on 27.04.2025.
//

import AppIntents
import Foundation

struct AddExpenseSiriIntent: AppIntent {
    static var title: LocalizedStringResource = "Add an Expense"
    static var description = IntentDescription("Quickly add a new expense to iExpense via Siri or Shortcuts.")

    static var openAppWhenRun: Bool = true

    @Parameter(title: "Title", description: "What was the expense for?")
    var title: String

    @Parameter(title: "Amount", description: "How much did you spend?")
    var amount: Double

    @Parameter(title: "Category", description: "Expense category")
    var category: Category

    static var parameterSummary: some ParameterSummary {
        Summary("Add \(\.$title) for \(\.$amount) in \(\.$category)")
    }

    func perform() async throws -> some IntentResult {
        var expenses = StorageService.loadExpenses()
        let newExpense = Expense(
            title: title,
            amount: amount,
            date: Date(),
            category: category
        )
        expenses.append(newExpense)
        StorageService.saveExpenses(expenses)

        return .result()
    }
}
