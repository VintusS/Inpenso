//
//  CategoryStore.swift
//  iExpense
//

import SwiftUI

@MainActor
final class CategoryStore: ObservableObject {
    @Published private(set) var customCategories: [FinanceCategory] = []

    var allCategories: [FinanceCategory] {
        FinanceCategory.builtInCategories + customCategories
    }

    init() {
        customCategories = StorageService.loadCustomCategories()
    }

    func category(for id: String) -> FinanceCategory {
        allCategories.first { $0.id == id } ?? FinanceCategory.fallback
    }

    func category(for transaction: Expense) -> FinanceCategory {
        category(for: transaction.categoryID)
    }

    func addCategory(name: String, iconName: String, colorHex: String) {
        let category = FinanceCategory(
            id: "custom-\(UUID().uuidString)",
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            iconName: iconName,
            colorHex: colorHex,
            isCustom: true
        )
        customCategories.append(category)
        save()
    }

    func updateCategory(_ category: FinanceCategory) {
        guard category.isCustom,
              let index = customCategories.firstIndex(where: { $0.id == category.id }) else {
            return
        }

        customCategories[index] = category
        save()
    }

    func deleteCategory(_ category: FinanceCategory) {
        guard category.isCustom else { return }
        customCategories.removeAll { $0.id == category.id }
        save()
    }

    private func save() {
        StorageService.saveCustomCategories(customCategories)
    }
}

