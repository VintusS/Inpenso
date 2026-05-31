//
//  CategoryStore.swift
//  iExpense
//

import SwiftUI

@MainActor
final class CategoryStore: ObservableObject {
    @Published private var catalogState: CategoryCatalogState

    var customCategories: [FinanceCategory] {
        catalogState.customCategories
    }

    var allCategories: [FinanceCategory] {
        visibleCategories
    }

    var visibleCategories: [FinanceCategory] {
        orderedCategories(includeHidden: false)
    }

    var hiddenCategories: [FinanceCategory] {
        orderedCategories(includeHidden: true)
            .filter { catalogState.hiddenCategoryIDs.contains($0.id) }
    }

    init() {
        if let savedCatalogState = StorageService.loadCategoryCatalogState() {
            catalogState = Self.normalized(savedCatalogState)
        } else {
            catalogState = Self.initialState(customCategories: StorageService.loadCustomCategories())
            save()
        }
    }

    func category(for id: String) -> FinanceCategory {
        categoryMap[id] ?? FinanceCategory.fallback
    }

    func category(for transaction: Expense) -> FinanceCategory {
        category(for: transaction.categoryID)
    }

    func categoriesForPicker(including categoryID: String? = nil) -> [FinanceCategory] {
        var categories = visibleCategories

        if let categoryID,
           !categoryID.isEmpty,
           !categories.contains(where: { $0.id == categoryID }),
           let category = categoryMap[categoryID] {
            categories.append(category)
        }

        return categories
    }

    func categoriesForFilter(usedCategoryIDs: Set<String>) -> [FinanceCategory] {
        let visible = visibleCategories
        let visibleIDs = Set(visible.map(\.id))
        let extraIDs = usedCategoryIDs.subtracting(visibleIDs)
        let extraCategories = orderedCategoryIDs(for: extraIDs).compactMap { categoryMap[$0] }

        return visible + extraCategories
    }

    func orderedCategoryIDs(for categoryIDs: Set<String>) -> [String] {
        let orderedIDs = catalogState.orderedCategoryIDs.filter { categoryIDs.contains($0) }
        let knownOrderedIDs = Set(orderedIDs)
        let unorderedIDs = categoryIDs.subtracting(knownOrderedIDs)
            .sorted {
                category(for: $0).displayName.localizedCaseInsensitiveCompare(category(for: $1).displayName) == .orderedAscending
            }

        return orderedIDs + unorderedIDs
    }

    func preferredCategoryID(for categoryID: String?) -> String {
        if let categoryID,
           !catalogState.hiddenCategoryIDs.contains(categoryID),
           categoryMap[categoryID] != nil {
            return categoryID
        }

        return visibleCategories.first?.id ?? FinanceCategory.fallback.id
    }

    func addCategory(name: String, iconName: String, colorHex: String) {
        let category = FinanceCategory(
            id: "custom-\(UUID().uuidString)",
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            iconName: iconName,
            colorHex: colorHex,
            isCustom: true
        )
        catalogState.customCategories.append(category)
        catalogState.orderedCategoryIDs.append(category.id)
        save()
    }

    func updateCategory(_ category: FinanceCategory) {
        if category.isCustom {
            guard let index = catalogState.customCategories.firstIndex(where: { $0.id == category.id }) else {
                return
            }

            var customCategory = category
            customCategory.isCustom = true
            catalogState.customCategories[index] = customCategory
        } else if Self.builtInCategoryIDs.contains(category.id) {
            var builtInOverride = category
            builtInOverride.isCustom = false
            catalogState.builtInOverrides[category.id] = builtInOverride
        } else {
            return
        }

        save()
    }

    func deleteCategory(_ category: FinanceCategory) {
        hideCategory(category)
    }

    func hideCategory(_ category: FinanceCategory) {
        guard categoryMap[category.id] != nil,
              !catalogState.hiddenCategoryIDs.contains(category.id),
              visibleCategories.count > 1 else {
            return
        }

        catalogState.hiddenCategoryIDs.insert(category.id)
        save()
    }

    func restoreCategory(_ category: FinanceCategory) {
        guard categoryMap[category.id] != nil else { return }

        catalogState.hiddenCategoryIDs.remove(category.id)
        if !catalogState.orderedCategoryIDs.contains(category.id) {
            catalogState.orderedCategoryIDs.append(category.id)
        }

        save()
    }

    func moveCategory(_ sourceID: String, to destinationID: String) {
        guard sourceID != destinationID,
              catalogState.orderedCategoryIDs.contains(sourceID),
              catalogState.orderedCategoryIDs.contains(destinationID) else {
            return
        }

        catalogState.orderedCategoryIDs.removeAll { $0 == sourceID }

        if let destinationIndex = catalogState.orderedCategoryIDs.firstIndex(of: destinationID) {
            catalogState.orderedCategoryIDs.insert(sourceID, at: destinationIndex)
        } else {
            catalogState.orderedCategoryIDs.append(sourceID)
        }

        save()
    }

    func resetBuiltInOverride(for categoryID: String) {
        guard Self.builtInCategoryIDs.contains(categoryID) else { return }
        catalogState.builtInOverrides.removeValue(forKey: categoryID)
        save()
    }

    func isHidden(_ categoryID: String) -> Bool {
        catalogState.hiddenCategoryIDs.contains(categoryID)
    }

    func hasBuiltInOverride(for categoryID: String) -> Bool {
        catalogState.builtInOverrides[categoryID] != nil
    }

    private func save() {
        catalogState = Self.normalized(catalogState)
        StorageService.saveCategoryCatalogState(catalogState)
        StorageService.saveCustomCategories(catalogState.customCategories)
    }

    private var categoryMap: [String: FinanceCategory] {
        Dictionary(uniqueKeysWithValues: allKnownCategories.map { ($0.id, $0) })
    }

    private var allKnownCategories: [FinanceCategory] {
        builtInCategories + catalogState.customCategories
    }

    private var builtInCategories: [FinanceCategory] {
        FinanceCategory.builtInCategories.map { category in
            catalogState.builtInOverrides[category.id] ?? category
        }
    }

    private func orderedCategories(includeHidden: Bool) -> [FinanceCategory] {
        let categoriesByID = categoryMap

        return catalogState.orderedCategoryIDs.compactMap { categoryID in
            guard includeHidden || !catalogState.hiddenCategoryIDs.contains(categoryID) else {
                return nil
            }

            return categoriesByID[categoryID]
        }
    }

    private static var builtInCategoryIDs: Set<String> {
        Set(FinanceCategory.builtInCategories.map(\.id))
    }

    private static func initialState(customCategories: [FinanceCategory]) -> CategoryCatalogState {
        let normalizedCustomCategories = customCategories.map { category in
            var category = category
            category.isCustom = true
            return category
        }

        return CategoryCatalogState(
            orderedCategoryIDs: FinanceCategory.builtInCategories.map(\.id) + normalizedCustomCategories.map(\.id),
            customCategories: normalizedCustomCategories
        )
    }

    private static func normalized(_ state: CategoryCatalogState) -> CategoryCatalogState {
        let builtInIDs = builtInCategoryIDs
        var normalized = state
        var seenCustomIDs = Set<String>()

        normalized.customCategories = normalized.customCategories.compactMap { category in
            guard !builtInIDs.contains(category.id),
                  !seenCustomIDs.contains(category.id) else {
                return nil
            }

            seenCustomIDs.insert(category.id)
            var category = category
            category.isCustom = true
            return category
        }

        normalized.builtInOverrides = normalized.builtInOverrides.reduce(into: [String: FinanceCategory]()) { result, item in
            guard builtInIDs.contains(item.key) else { return }
            var category = item.value
            category.id = item.key
            category.isCustom = false
            result[item.key] = category
        }

        let knownCategoryIDs = FinanceCategory.builtInCategories.map(\.id) + normalized.customCategories.map(\.id)
        let knownCategoryIDSet = Set(knownCategoryIDs)
        var orderedCategoryIDs: [String] = []
        var seenOrderedIDs = Set<String>()

        for categoryID in normalized.orderedCategoryIDs where knownCategoryIDSet.contains(categoryID) && !seenOrderedIDs.contains(categoryID) {
            orderedCategoryIDs.append(categoryID)
            seenOrderedIDs.insert(categoryID)
        }

        for categoryID in knownCategoryIDs where !seenOrderedIDs.contains(categoryID) {
            orderedCategoryIDs.append(categoryID)
        }

        normalized.orderedCategoryIDs = orderedCategoryIDs
        normalized.hiddenCategoryIDs = normalized.hiddenCategoryIDs.intersection(knownCategoryIDSet)

        return normalized
    }
}
