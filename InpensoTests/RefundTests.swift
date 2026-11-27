import XCTest
@testable import Inpenso

final class RefundTests: XCTestCase {
    private func purchase(_ price: Double, on date: Date, category: Inpenso.Category = .shopping) -> Expense {
        Expense(title: "Online store", price: price, date: date, category: category)
    }

    private func refund(_ price: Double, on date: Date, of purchase: Expense? = nil, category: Inpenso.Category = .shopping) -> Expense {
        Expense(title: "Refund", price: price, date: date, category: category, type: .refund, refundOfID: purchase?.id)
    }

    func testLinkedRefundCountsOnPurchaseDate() {
        let order = purchase(100_000, on: TestFixtures.date(2_026, 11, 28, hour: 12))
        let late = refund(40_000, on: TestFixtures.date(2_026, 12, 3, hour: 12), of: order)

        let entries = [order, late].spendingEntries

        XCTAssertEqual(entries.map(\.amount), [100_000, -40_000])
        XCTAssertEqual(entries[1].date, order.date)
        XCTAssertEqual(entries[1].categoryID, Category.shopping.categoryID)
    }

    func testUnlinkedRefundCountsOnItsOwnDateAndIncomeIsNotSpending() {
        let cashback = refund(25_000, on: TestFixtures.date(2_026, 11, 16, hour: 12))
        let salary = Expense(title: "Salary", price: 8_000_000, date: cashback.date, category: .salary, type: .income)

        let entries = [cashback, salary].spendingEntries

        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].amount, -25_000)
        XCTAssertEqual(entries[0].date, cashback.date)
    }

    @MainActor
    func testAnalyticsNetsRefundIntoPurchaseMonth() {
        let order = purchase(100_000, on: TestFixtures.date(2_026, 11, 15, hour: 12))
        let late = refund(40_000, on: TestFixtures.date(2_026, 12, 3, hour: 12), of: order)
        let analytics = AnalyticsViewModel(expenses: [order, late])

        analytics.selectedMonth = 11
        analytics.selectedYear = 2_026
        analytics.calculateAnalytics()
        XCTAssertEqual(analytics.totalSpent, 60_000)
        XCTAssertEqual(analytics.totalIncome, 0)
        XCTAssertEqual(analytics.spendingByCategory[Category.shopping.categoryID], 60_000)

        analytics.selectedMonth = 12
        analytics.calculateAnalytics()
        XCTAssertEqual(analytics.totalSpent, 0)
    }

    func testLinkedRefundFollowsRecategorizedPurchase() {
        var order = purchase(100_000, on: TestFixtures.date(2_026, 11, 10, hour: 12))
        let back = refund(40_000, on: TestFixtures.date(2_026, 11, 12, hour: 12), of: order)
        order.categoryID = Category.work.categoryID

        let entries = [order, back].spendingEntries

        XCTAssertEqual(entries.map(\.categoryID), [Category.work.categoryID, Category.work.categoryID])
    }

    @MainActor
    func testCashflowUsesTransactionDatesAndDailyChartMatchesSpending() {
        let order = purchase(100_000, on: TestFixtures.date(2_026, 11, 10, hour: 12))
        let late = refund(40_000, on: TestFixtures.date(2_026, 12, 3, hour: 12), of: order)
        let cashback = refund(10_000, on: TestFixtures.date(2_026, 11, 20, hour: 12))
        let analytics = AnalyticsViewModel(expenses: [order, late, cashback])

        analytics.selectedMonth = 11
        analytics.selectedYear = 2_026
        analytics.calculateAnalytics()
        XCTAssertEqual(analytics.totalSpent, 50_000)
        XCTAssertEqual(analytics.netCashflow, -90_000)
        XCTAssertEqual(analytics.dailySpending.reduce(0) { $0 + $1.amount }, 50_000)

        // December only receives the refund: no spending, positive cash flow.
        analytics.selectedMonth = 12
        analytics.calculateAnalytics()
        XCTAssertEqual(analytics.totalSpent, 0)
        XCTAssertEqual(analytics.netCashflow, 40_000)
    }

    func testRefundAddsToWalletBalance() throws {
        var ledger = TestFixtures.ledger()
        let bank = ledger.wallets[0].id
        var order = purchase(100_000, on: TestFixtures.date(2_026, 11, 1))
        order.walletID = bank
        var back = refund(30_000, on: TestFixtures.date(2_026, 11, 2), of: order)
        back.walletID = bank
        ledger.transactions = [order, back]
        try ledger.prepareForWrite()

        let net = ledger.transactions.reduce(0) { $0 + $1.signedAmount }
        XCTAssertEqual(net, -70_000)
    }

    func testIncomeInExpenseCategoriesMovesToIncomeCategories() throws {
        var ledger = TestFixtures.ledger()
        let salary = Expense(title: "Salary", price: 1, date: Date(), category: .work, type: .income)
        let interest = Expense(title: "Interest", price: 1, date: Date(), category: .others, type: .income)
        let refundInIncome = Expense(title: "Refund", price: 1, date: Date(), category: .salary, type: .refund)
        var linkedIncome = Expense(title: "Odd", price: 1, date: Date(), category: .otherIncome, type: .income)
        linkedIncome.refundOfID = UUID()
        let custom = Expense(
            title: "Side job", price: 1, date: Date(), category: .others, type: .income, categoryID: "custom-side"
        )
        ledger.transactions = [salary, interest, refundInIncome, linkedIncome, custom]

        try ledger.prepareForWrite()

        XCTAssertEqual(ledger.transactions.map(\.categoryID), [
            Category.salary.categoryID, Category.otherIncome.categoryID, Category.others.categoryID,
            Category.otherIncome.categoryID, "custom-side",
        ])
        XCTAssertEqual(ledger.transactions[0].category, .salary)
        XCTAssertNil(ledger.transactions[3].refundOfID)
    }
}
