//
//  ExpenseViewModel.swift
//  iExpense
//
//  Created by Dragomir Mindrescu on 27.04.2025.
//

import Foundation
import SwiftUI

@MainActor
class ExpenseViewModel: ObservableObject {
    @Published var expenses: [Expense] = []
    
    init() {
        loadExpenses()
    }
    
    func addExpense(title: String, amount: Double, category: Category) {
        let newExpense = Expense(title: title, amount: amount, date: Date(), category: category)
        expenses.append(newExpense)
        saveExpenses()
    }
    
    func deleteExpense(at offsets: IndexSet) {
        expenses.remove(atOffsets: offsets)
        saveExpenses()
    }
    
    func saveExpenses() {
        StorageService.saveExpenses(expenses)
    }

    func loadExpenses() {
        expenses = StorageService.loadExpenses()
    }

}
