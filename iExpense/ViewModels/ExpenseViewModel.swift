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
    
    func addExpense(title: String, price: Double, date: Date, category: Category) -> Expense {
        let newExpense = Expense(title: title, price: price, date: date, category: category)
        expenses.append(newExpense)
        saveExpenses()
        return newExpense
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
    
    func deleteExpenses(_ expenses: [Expense]) {
        for expense in expenses {
            if let index = self.expenses.firstIndex(where: { $0.id == expense.id }) {
                self.expenses.remove(at: index)
            }
        }
        saveExpenses()
    }

}
