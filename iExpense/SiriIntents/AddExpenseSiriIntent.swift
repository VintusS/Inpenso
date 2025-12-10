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
    static var description = IntentDescription("Quickly add a new expense to iExpense via Voice Control or Shortcuts.")

    static var openAppWhenRun: Bool = false

    static var dialog: IntentDialog {
        IntentDialog("Let's add a new expense.")
    }

    @Parameter(title: "Expense Name")
    var title: String

    @Parameter(title: "Expense Price")
    var price: Double

    @Parameter(title: "Expense Category")
    var category: Category

    static var parameterSummary: some ParameterSummary {
        Summary("What did you spend money on? \(\.$title), how much did you spend? \(\.$price), and what category does it belong to? \(\.$category)")
    }

    func perform() async throws -> some IntentResult {
        var expenses = StorageService.loadExpenses()
        let newExpense = Expense(
            title: title,
            price: price,
            date: Date(),
            category: category
        )
        expenses.append(newExpense)
        StorageService.saveExpenses(expenses)

        return .result()
    }
}
