//
//  SwiftDataServiceModels.swift
//  iExpense
//
//  Created by Dragomir Mindrescu on 27.04.2025.
//

import Foundation
import SwiftData

// This file provides access to the basic model types needed by SwiftDataService
// It can be included in any target without causing redeclaration errors

// MARK: - Type Aliases

// Using typealiases to reference the SwiftData models
// This prevents redeclaration errors with the original models
private typealias SDExpenseItem = ExpenseItem
private typealias SDBudgetItem = BudgetItem

// MARK: - SwiftData Extensions

// Add extensions to access the models safely
extension ModelContext {
    // Safe wrapper to fetch budget items
    func fetchBudgetItems() throws -> [BudgetItem] {
        let descriptor = FetchDescriptor<BudgetItem>()
        return try fetch(descriptor)
    }
    
    // Safe wrapper to fetch expense items
    func fetchExpenseItems() throws -> [ExpenseItem] {
        let descriptor = FetchDescriptor<ExpenseItem>()
        return try fetch(descriptor)
    }
    
    // Fetch budget for a specific month/year
    func fetchBudget(monthYear: String) throws -> BudgetItem? {
        let descriptor = FetchDescriptor<BudgetItem>(
            predicate: #Predicate { budget in
                budget.monthYear == monthYear
            }
        )
        return try fetch(descriptor).first
    }
    
    // Delete all expenses
    func deleteAllExpenses() throws {
        let items = try fetchExpenseItems()
        for item in items {
            delete(item)
        }
        try save()
    }
    
    // Delete all budgets
    func deleteAllBudgets() throws {
        let items = try fetchBudgetItems()
        for item in items {
            delete(item)
        }
        try save()
    }
} 
