//
//  StorageService.swift
//  iExpense
//
//  Created by Dragomir Mindrescu on 27.04.2025.
//

import Foundation

struct StorageService {
    private static let expensesKey = "expenses"

    static func saveExpenses(_ expenses: [Expense]) {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(expenses)
            UserDefaults.standard.set(data, forKey: expensesKey)
        } catch {
            print("Error saving expenses: \(error.localizedDescription)")
        }
    }

    static func loadExpenses() -> [Expense] {
        guard let data = UserDefaults.standard.data(forKey: expensesKey) else {
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

    static func clearExpenses() {
        UserDefaults.standard.removeObject(forKey: expensesKey)
    }
}
