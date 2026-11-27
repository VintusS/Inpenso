//
//  CategoryStore.swift
//  iExpense
//

import SwiftUI

@MainActor
final class CategoryStore: ObservableObject {
    @Published private var catalogState: CategoryCatalogState
    /// Entries per category over the last `usageWindowDays`, for most-used sorting.
    @Published private var usageCounts: [String: Int] = [:]

    static let usageWindowDays = 90

    var sortsByUsage: Bool { catalogState.sortsByUsage }

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

    /// Re-reads the catalog from storage, e.g. after a backup restore.
    func reload() {
        if let savedCatalogState = StorageService.loadCategoryCatalogState() {
            catalogState = Self.normalized(savedCatalogState)
        } else {
            catalogState = Self.initialState(customCategories: StorageService.loadCustomCategories())
        }
    }

    func category(for id: String) -> FinanceCategory {
        categoryMap[id] ?? FinanceCategory.fallback
    }

    func category(for transaction: Expense) -> FinanceCategory {
        category(for: transaction.categoryID)
    }

    /// Visible categories of one kind, plus `categoryID` when it is hidden or of the other kind
    /// so an existing entry keeps showing its category.
    func categoriesForPicker(kind: CategoryKind, including categoryID: String? = nil) -> [FinanceCategory] {
        var categories = visibleCategories.filter { $0.kind == kind }

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
        let resolvedIDs = Set(usedCategoryIDs.map { category(for: $0).id })
        let extraIDs = resolvedIDs.subtracting(visibleIDs)
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

    func preferredCategoryID(for categoryID: String?, kind: CategoryKind = .expense) -> String {
        if let categoryID,
           !catalogState.hiddenCategoryIDs.contains(categoryID),
           categoryMap[categoryID]?.kind == kind {
            return categoryID
        }

        return visibleCategories.first { $0.kind == kind }?.id ?? FinanceCategory.fallback(for: kind).id
    }

    func addCategory(name: String, iconName: String, colorHex: String, kind: CategoryKind = .expense) {
        let category = FinanceCategory(
            id: "custom-\(UUID().uuidString)",
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            iconName: iconName,
            colorHex: colorHex,
            isCustom: true,
            kind: kind
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
        } else if let builtIn = FinanceCategory.builtInCategories.first(where: { $0.id == category.id }) {
            var builtInOverride = category
            builtInOverride.isCustom = false
            builtInOverride.kind = builtIn.kind
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
              visibleCategories.filter({ $0.kind == category.kind }).count > 1 else {
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
              catalogState.orderedCategoryIDs.contains(destinationID),
              categoryMap[sourceID]?.kind == categoryMap[destinationID]?.kind else {
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
        let manual = manualOrder(includeHidden: includeHidden)
        return catalogState.sortsByUsage ? byUsage(manual) : manual
    }

    private func manualOrder(includeHidden: Bool) -> [FinanceCategory] {
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

        let builtInKinds = Dictionary(uniqueKeysWithValues: FinanceCategory.builtInCategories.map { ($0.id, $0.kind) })
        normalized.builtInOverrides = normalized.builtInOverrides.reduce(into: [String: FinanceCategory]()) { result, item in
            guard let kind = builtInKinds[item.key] else { return }
            var category = item.value
            category.id = item.key
            category.isCustom = false
            category.kind = kind
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

// MARK: - Sorting

extension CategoryStore {
    /// Recounts usage from the current transactions. Refunds count toward their expense category.
    func updateUsage(from transactions: [Expense], now: Date = Date()) {
        let cutoff = Calendar.current.date(byAdding: .day, value: -Self.usageWindowDays, to: now) ?? now
        let counts = transactions
            .filter { $0.date >= cutoff && $0.date <= now }
            .reduce(into: [String: Int]()) { $0[$1.categoryID, default: 0] += 1 }
        if counts != usageCounts { usageCounts = counts }
    }

    func usageCount(for categoryID: String) -> Int {
        usageCounts[categoryID] ?? 0
    }

    func setSortsByUsage(_ enabled: Bool) {
        guard enabled != catalogState.sortsByUsage else { return }
        catalogState.sortsByUsage = enabled
        save()
    }

    /// Saves the current most-used order as the manual order of one kind.
    func sortByUsage(kind: CategoryKind) {
        reorder(kind: kind) { byUsage($0) }
    }

    func sortAlphabetically(kind: CategoryKind) {
        reorder(kind: kind) { categories in
            categories.sorted { $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending }
        }
    }

    /// Manual order of one kind's visible categories, for the reorder list.
    func manuallyOrderedCategories(kind: CategoryKind) -> [FinanceCategory] {
        manualOrder(includeHidden: false).filter { $0.kind == kind }
    }

    func moveCategories(kind: CategoryKind, fromOffsets source: IndexSet, toOffset destination: Int) {
        reorder(kind: kind) { categories in
            var visible = categories.filter { !catalogState.hiddenCategoryIDs.contains($0.id) }
            visible.move(fromOffsets: source, toOffset: destination)
            return visible + categories.filter { catalogState.hiddenCategoryIDs.contains($0.id) }
        }
    }

    /// Rewrites the order of one kind's categories in the slots they already hold,
    /// so the other kind's order is untouched.
    private func reorder(kind: CategoryKind, _ arrange: ([FinanceCategory]) -> [FinanceCategory]) {
        let categoriesByID = categoryMap
        let slots = catalogState.orderedCategoryIDs.indices.filter {
            categoriesByID[catalogState.orderedCategoryIDs[$0]]?.kind == kind
        }
        let arranged = arrange(slots.compactMap { categoriesByID[catalogState.orderedCategoryIDs[$0]] })
        guard arranged.count == slots.count else { return }
        for (slot, category) in zip(slots, arranged) {
            catalogState.orderedCategoryIDs[slot] = category.id
        }
        save()
    }

    /// Most used first; ties keep their current order.
    private func byUsage(_ categories: [FinanceCategory]) -> [FinanceCategory] {
        categories.enumerated()
            .sorted { lhs, rhs in
                let lhsCount = usageCount(for: lhs.element.id)
                let rhsCount = usageCount(for: rhs.element.id)
                return lhsCount == rhsCount ? lhs.offset < rhs.offset : lhsCount > rhsCount
            }
            .map(\.element)
    }
}
