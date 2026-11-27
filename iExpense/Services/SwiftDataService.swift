//
//  SwiftDataService.swift
//  iExpense
//
//  Created by Dragomir Mindrescu on 27.04.2025.
//

import Foundation
import SwiftData
import SwiftUI

// Local reference to resolve module issues
// Using the locally defined extension methods to avoid explicit type dependencies

/// Service for accessing SwiftData from Intents and Widgets
/// This provides access to SwiftData operations when a view context isn't available
@MainActor
struct SwiftDataService {
    static func saveExpense(title: String, price: Double, date: Date, category: Category) {
        Task { @MainActor in
            guard let container = try? SwiftDataManager.shared.createContainer() else {
                print("Failed to create container for quick expense")
                return
            }
            
            let context = container.mainContext
            
            // Create the regular Expense model for UserDefaults
            let expense = Expense(title: title, price: price, date: date, category: category)
            
            // Let SwiftDataManager handle SwiftData operations
            try? SwiftDataManager.shared.saveExpense(expense, using: context)
            
            StorageService.updateExpenses { $0.append(expense) }
        }
    }
    
    static func clearAllData() {
        Task { @MainActor in
            guard let container = try? SwiftDataManager.shared.createContainer() else {
                print("Failed to create container for clearing data")
                return
            }
            
            let context = container.mainContext
            
            do {
                // Delete all expenses
                let expenseDescriptor = FetchDescriptor<ExpenseItem>()
                let expenses = try context.fetch(expenseDescriptor)
                for expense in expenses {
                    context.delete(expense)
                }
                
                // Delete all budgets
                let budgetDescriptor = FetchDescriptor<BudgetItem>()
                let budgets = try context.fetch(budgetDescriptor)
                for budget in budgets {
                    context.delete(budget)
                }
                
                try context.save()
                
                // Also clear the shared transaction and budget stores
                try StorageService.clearExpenses()
                StorageService.saveBudgets([:])
            } catch {
                print("Failed to clear data: \(error)")
            }
        }
    }
}
