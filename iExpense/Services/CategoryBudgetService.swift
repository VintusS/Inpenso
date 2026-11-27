//
//  CategoryBudgetService.swift
//  iExpense
//

import Foundation

/// Standing monthly spending limits per category, keyed by category ID.
/// A limit applies to every month until changed.
enum CategoryBudgetService {
    private static let key = "categoryBudgets"

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: StorageService.appGroupID)
    }

    static func load() -> [String: Double] {
        guard let data = defaults?.data(forKey: key),
              let budgets = try? JSONDecoder().decode([String: Double].self, from: data) else {
            return [:]
        }
        return budgets
    }

    static func save(_ budgets: [String: Double]) {
        let positive = budgets.filter { $0.value > 0 }
        guard let data = try? JSONEncoder().encode(positive) else { return }
        defaults?.set(data, forKey: key)
    }
}
