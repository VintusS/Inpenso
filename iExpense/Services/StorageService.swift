//
//  StorageService.swift
//  iExpense
//
//  Created by Dragomir Mindrescu on 27.04.2025.
//

import Foundation

struct StorageService {
    static let appGroupID = "group.com.vintuss.iexpense"

    private static var userDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroupID)
    }

    private static let expensesKey = "expenses"
    private static let budgetsKey = "budgets"

    static func saveExpenses(_ expenses: [Expense]) {
        guard let userDefaults = userDefaults else { return }
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(expenses)
            userDefaults.set(data, forKey: expensesKey)
        } catch {
            print("Error saving expenses: \(error.localizedDescription)")
        }
    }

    static func loadExpenses() -> [Expense] {
        guard let userDefaults = userDefaults,
              let data = userDefaults.data(forKey: expensesKey) else {
            return []
        }
        do {
            let decoder = JSONDecoder()
            let expenses = try decoder.decode([Expense].self, from: data)
            return expenses
        } catch {
            print("Error loading expenses: \(error.localizedDescription)")
            return []
        }
    }
    
    static func saveBudgets(_ budgets: [String: Double]) {
        guard let userDefaults = userDefaults else { return }
        do {
            let data = try JSONEncoder().encode(budgets)
            userDefaults.set(data, forKey: budgetsKey)
        } catch {
            print("Error saving budgets: \(error.localizedDescription)")
        }
    }

    static func loadBudgets() -> [String: Double] {
        guard let userDefaults = userDefaults,
              let data = userDefaults.data(forKey: budgetsKey) else {
            return [:]
        }
        do {
            let budgets = try JSONDecoder().decode([String: Double].self, from: data)
            return budgets
        } catch {
            print("Error loading budgets: \(error.localizedDescription)")
            return [:]
        }
    }

    static func clearExpenses() {
        guard let userDefaults = userDefaults else { return }
        userDefaults.removeObject(forKey: expensesKey)
    }
}
