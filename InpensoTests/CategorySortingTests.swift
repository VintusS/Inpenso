import XCTest
@testable import Inpenso

@MainActor
final class CategorySortingTests: XCTestCase {
    private var store: CategoryStore!

    override func setUpWithError() throws {
        try super.setUpWithError()
        guard StorageService.isUnitTestHost else { throw XCTSkip("Needs the unit-test host for isolated defaults") }
        store = CategoryStore()
        CategoryKind.allCases.forEach(store.sortAlphabetically(kind:))
        store.setSortsByUsage(false)
        addTeardownBlock { @MainActor in
            self.store.setSortsByUsage(false)
        }
    }

    private func ids(_ kind: CategoryKind) -> [String] {
        store.categoriesForPicker(kind: kind).map(\.id)
    }

    private func entry(_ category: Inpenso.Category, daysAgo: Int = 1) -> Expense {
        Expense(
            title: "x", price: 1, date: Date().addingTimeInterval(-Double(daysAgo) * 86_400), category: category,
            type: category.kind == .income ? .income : .expense
        )
    }

    func testFilterIncludesFallbackForUnmappedUsedCategory() {
        let fallback = FinanceCategory.fallback
        let wasHidden = store.isHidden(fallback.id)
        store.hideCategory(fallback)
        defer {
            if !wasHidden { store.restoreCategory(fallback) }
        }

        XCTAssertFalse(store.categoriesForFilter(usedCategoryIDs: []).contains { $0.id == fallback.id })
        let legacyID = "unmapped-legacy-category"
        let resolvedID = store.category(for: legacyID).id
        let filterIDs = store.categoriesForFilter(usedCategoryIDs: [legacyID]).map(\.id)

        XCTAssertEqual(resolvedID, fallback.id)
        XCTAssertEqual(filterIDs.filter { $0 == resolvedID }.count, 1)
    }

    func testAlphabeticalSortKeepsKindsSeparate() {
        let expenseNames = store.categoriesForPicker(kind: .expense).map(\.displayName)
        XCTAssertEqual(expenseNames, expenseNames.sorted { $0.localizedStandardCompare($1) == .orderedAscending })
        XCTAssertTrue(ids(.income).allSatisfy { store.category(for: $0).kind == .income })
    }

    func testAlwaysSortByUsageUsesRecentEntriesOnly() {
        store.updateUsage(from: [
            entry(.transportation), entry(.transportation), entry(.food),
            entry(.rent, daysAgo: 200), entry(.rent, daysAgo: 200), entry(.rent, daysAgo: 200),
        ])
        let manual = ids(.expense)

        store.setSortsByUsage(true)
        XCTAssertEqual(Array(ids(.expense).prefix(2)), [Category.transportation.categoryID, Category.food.categoryID])

        store.setSortsByUsage(false)
        XCTAssertEqual(ids(.expense), manual)
    }

    func testSortOnceByUsageAndManualMoveStayWithinKind() {
        let incomeBefore = ids(.income)
        store.updateUsage(from: [entry(.utilities), entry(.utilities), entry(.shopping)])

        store.sortByUsage(kind: .expense)
        XCTAssertEqual(Array(ids(.expense).prefix(2)), [Category.utilities.categoryID, Category.shopping.categoryID])
        XCTAssertEqual(ids(.income), incomeBefore)

        store.moveCategories(kind: .expense, fromOffsets: IndexSet(integer: 0), toOffset: 3)
        XCTAssertEqual(ids(.expense)[2], Category.utilities.categoryID)
        XCTAssertEqual(ids(.income), incomeBefore)
    }
}
