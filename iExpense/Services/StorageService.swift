//
//  StorageService.swift
//  iExpense
//
//  Created by Dragomir Mindrescu on 27.04.2025.
//

import Foundation

struct StorageService {
    static let appGroupID = "group.com.vintuss.Inpenso"

    private static var userDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroupID)
    }

    private static let expensesKey = "expenses"
    private static let budgetsKey = "budgets"
    private static let categoryCatalogStateKey = "categoryCatalogState"
    private static let customCategoriesKey = "customCategories"

    static func saveExpenses(_ expenses: [Expense]) {
        guard let userDefaults = userDefaults else { return }
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(expenses)
            userDefaults.set(data, forKey: expensesKey)
        } catch {
            // Error handling without print
        }
    }

    static func loadExpenses() -> [Expense] {
        guard let userDefaults = userDefaults,
              let data = userDefaults.data(forKey: expensesKey) else {
            return []
        }
        do {
            let decoder = JSONDecoder()
            var expenses = try decoder.decode([Expense].self, from: data)
            var needsSave = false

            for index in expenses.indices {
                if expenses[index].categoryID.isEmpty {
                    expenses[index].categoryID = expenses[index].category.categoryID
                    needsSave = true
                }

                if expenses[index].notes == nil {
                    let notesKey = "notes_\(expenses[index].id.uuidString)"
                    if let legacyNotes = UserDefaults.standard.string(forKey: notesKey),
                       !legacyNotes.isEmpty {
                        expenses[index].notes = legacyNotes
                        needsSave = true
                    }
                }
            }

            if needsSave {
                saveExpenses(expenses)
            }

            return expenses
        } catch {
            // Error handling without print
            return []
        }
    }
    
    static func saveBudgets(_ budgets: [String: Double]) {
        guard let userDefaults = userDefaults else { return }
        do {
            let data = try JSONEncoder().encode(budgets)
            userDefaults.set(data, forKey: budgetsKey)
        } catch {
            // Error handling without print
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
            // Error handling without print
            return [:]
        }
    }

    static func clearExpenses() {
        guard let userDefaults = userDefaults else { return }
        userDefaults.removeObject(forKey: expensesKey)
    }

    static func saveCustomCategories(_ categories: [FinanceCategory]) {
        guard let userDefaults = userDefaults else { return }
        do {
            let data = try JSONEncoder().encode(categories)
            userDefaults.set(data, forKey: customCategoriesKey)
        } catch {
            // Error handling without print
        }
    }

    static func loadCustomCategories() -> [FinanceCategory] {
        guard let userDefaults = userDefaults,
              let data = userDefaults.data(forKey: customCategoriesKey) else {
            return []
        }

        do {
            return try JSONDecoder().decode([FinanceCategory].self, from: data)
        } catch {
            return []
        }
    }

    static func saveCategoryCatalogState(_ state: CategoryCatalogState) {
        guard let userDefaults = userDefaults else { return }
        do {
            let data = try JSONEncoder().encode(state)
            userDefaults.set(data, forKey: categoryCatalogStateKey)
        } catch {
            // Error handling without print
        }
    }

    static func loadCategoryCatalogState() -> CategoryCatalogState? {
        guard let userDefaults = userDefaults,
              let data = userDefaults.data(forKey: categoryCatalogStateKey) else {
            return nil
        }

        do {
            return try JSONDecoder().decode(CategoryCatalogState.self, from: data)
        } catch {
            return nil
        }
    }
}
