//
//  SwiftDataManager.swift
//  iExpense
//
//  Created by Dragomir Mindrescu on 27.04.2025.
//

import Foundation
import SwiftData

// This class will manage all SwiftData operations
// It doesn't modify any existing functionality and can be used in parallel
class SwiftDataManager {
    
    // Singleton instance
    static let shared = SwiftDataManager()
    
    // Private initializer for singleton
    private init() {}
    
    // MARK: - Create a ModelContainer
    
    func createContainer() throws -> ModelContainer {
        let schema = Schema([
            ExpenseItem.self,
            BudgetItem.self
        ])
        
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            allowsSave: true
        )
        
        return try ModelContainer(for: schema, configurations: [modelConfiguration])
    }
    
    // MARK: - Migration
    
    // Migrates data from UserDefaults to SwiftData without affecting current functionality
    func migrateData(using context: ModelContext) async throws {
        // Check if migration has already been done
        if UserDefaults.standard.bool(forKey: "swiftDataMigrationCompleted") {
            return
        }
        
        // Migrate expenses
        try await migrateExpenses(using: context)
        
        // Migrate budgets
        try await migrateBudgets(using: context)
        
        // Mark migration as completed
        UserDefaults.standard.set(true, forKey: "swiftDataMigrationCompleted")
    }
    
    private func migrateExpenses(using context: ModelContext) async throws {
        // Load expenses from UserDefaults
        let existingExpenses = StorageService.loadExpenses()
        
        // Convert and save each expense
        for expense in existingExpenses {
            let item = ExpenseItem(
                id: expense.id.uuidString,
                name: expense.title,
                amount: expense.price,
                date: expense.date,
                categoryName: expense.category.rawValue
            )
            
            context.insert(item)
        }
        
        try context.save()
    }
    
    private func migrateBudgets(using context: ModelContext) async throws {
        // Load budgets from UserDefaults
        let existingBudgets = StorageService.loadBudgets()
        
        // Convert and save each budget
        for (monthYear, amount) in existingBudgets {
            let budget = BudgetItem(monthYear: monthYear, amount: amount)
            context.insert(budget)
        }
        
        try context.save()
    }
    
    // MARK: - Read Operations
    
    func getAllExpenses(using context: ModelContext) throws -> [ExpenseItem] {
        let descriptor = FetchDescriptor<ExpenseItem>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        return try context.fetch(descriptor)
    }
    
    func getMonthlyExpenses(for date: Date, using context: ModelContext) throws -> [ExpenseItem] {
        let calendar = Calendar.current
        let month = calendar.component(.month, from: date)
        let year = calendar.component(.year, from: date)
        
        let startOfMonth = calendar.date(from: DateComponents(year: year, month: month, day: 1))!
        let nextMonth = calendar.date(byAdding: .month, value: 1, to: startOfMonth)!
        
        let descriptor = FetchDescriptor<ExpenseItem>(
            predicate: #Predicate { expense in
                expense.date >= startOfMonth && expense.date < nextMonth
            },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        
        return try context.fetch(descriptor)
    }
    
    func getBudget(for date: Date, using context: ModelContext) throws -> BudgetItem? {
        let monthYear = BudgetItem.monthYearString(from: date)
        
        let descriptor = FetchDescriptor<BudgetItem>(
            predicate: #Predicate { budget in
                budget.monthYear == monthYear
            }
        )
        
        return try context.fetch(descriptor).first
    }
    
    // MARK: - Write Operations
    
    func saveExpense(_ expense: Expense, using context: ModelContext) throws {
        // Convert from the app's Expense model to SwiftData's ExpenseItem
        let item = ExpenseItem(
            id: expense.id.uuidString,
            name: expense.title,
            amount: expense.price,
            date: expense.date,
            categoryName: expense.category.rawValue
        )
        
        context.insert(item)
        try context.save()
    }
    
    func saveBudget(monthYear: String, amount: Double, using context: ModelContext) throws {
        // Check if budget already exists
        let descriptor = FetchDescriptor<BudgetItem>(
            predicate: #Predicate { budget in
                budget.monthYear == monthYear
            }
        )
        
        if let existingBudget = try context.fetch(descriptor).first {
            // Update existing budget
            existingBudget.amount = amount
        } else {
            // Create new budget
            let budget = BudgetItem(monthYear: monthYear, amount: amount)
            context.insert(budget)
        }
        
        try context.save()
    }
    
    func deleteExpense(id: String, using context: ModelContext) throws {
        let descriptor = FetchDescriptor<ExpenseItem>(
            predicate: #Predicate { expense in
                expense.id == id
            }
        )
        
        if let item = try context.fetch(descriptor).first {
            context.delete(item)
            try context.save()
        }
    }
} 