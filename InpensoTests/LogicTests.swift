import XCTest
@testable import Inpenso

final class LogicTests: XCTestCase {
    func testZeroDecimalCurrencyInput() {
        for currency in ["IDR", "JPY"] {
            let input = AmountInput(fractionDigits: currencyFractionDigits(for: currency), locale: Locale(identifier: "id_ID"))
            XCTAssertEqual(input.fractionDigits, 0, currency)
            XCTAssertEqual(input.value(of: input.updating("", with: "125.000")), 125_000, currency)
            XCTAssertEqual(input.updating("", with: "000125000"), "125000", currency)
            let typed = input.updating("12500", with: "12.5000")
            XCTAssertEqual(input.display(typed), "125.000", currency)
            XCTAssertNil(input.value(of: input.updating("", with: "-125.000")), currency)
        }
    }

    func testUSDInputKeepsTwoDecimalPlaces() {
        let input = AmountInput(fractionDigits: currencyFractionDigits(for: "USD"), locale: Locale(identifier: "en_US"))
        XCTAssertEqual(input.fractionDigits, 2)
        let pasted = input.updating("", with: "$1,234.567")
        XCTAssertEqual(pasted, "1234.56")
        XCTAssertEqual(input.value(of: pasted), 1_234.56)
        XCTAssertEqual(input.display(pasted), "1,234.56")
    }

    func testBudgetCarriesForwardAcrossYears() {
        let budgets: [String: Double] = ["09-2024": 100, "12-2024": 250, "03-2025": 300]
        XCTAssertEqual(StorageService.effectiveBudget(month: 1, year: 2_025, in: budgets), 250)
        XCTAssertEqual(StorageService.effectiveBudget(month: 3, year: 2_025, in: budgets), 300)
        XCTAssertEqual(StorageService.effectiveBudget(month: 8, year: 2_024, in: budgets), 0)
    }

    func testMonthlyOccurrencesClampShortMonthsAndHonorSkips() {
        var rule = TestFixtures.rule(startDate: TestFixtures.date(2_024, 1, 15, hour: 13), day: 31)
        rule.skippedMonths = ["2024-03"]
        let now = TestFixtures.date(2_024, 4, 29)
        let occurrences = RecurringService.dueOccurrences(rules: [rule], postedIDs: [], now: now, calendar: TestFixtures.calendar)
        XCTAssertEqual(occurrences.map(\.monthKey), ["2024-01", "2024-02"])
        XCTAssertEqual(occurrences.map(\.dueDate), [TestFixtures.date(2_024, 1, 31), TestFixtures.date(2_024, 2, 29)])
        let remaining = RecurringService.dueOccurrences(
            rules: [rule], postedIDs: Set(occurrences.prefix(1).map(\.id)), now: now, calendar: TestFixtures.calendar
        )
        XCTAssertEqual(remaining.map(\.id), Array(occurrences.dropFirst().map(\.id)))
        XCTAssertEqual(Set(occurrences.map(\.id)).count, 2)
    }

    func testDayOneNormalizesToMidnight() {
        let rule = TestFixtures.rule(startDate: TestFixtures.date(2_025, 1, 1, hour: 13), day: 1)
        let occurrences = RecurringService.dueOccurrences(
            rules: [rule], postedIDs: [], now: TestFixtures.date(2_025, 2, 1), calendar: TestFixtures.calendar
        )
        XCTAssertEqual(occurrences.map(\.dueDate), [TestFixtures.date(2_025, 1, 1), TestFixtures.date(2_025, 2, 1)])
    }

    func testPrepareForWriteReplacesStaleFeeRows() throws {
        var ledger = TestFixtures.ledger()
        var transfer = TestFixtures.transfer(in: ledger)
        let feeID = UUID()
        transfer.feeExpenseID = feeID
        ledger.transfers = [transfer]
        let stale = Expense(id: feeID, title: "Stale", price: 1, date: transfer.date, category: .others)
        let ordinary = Expense(title: "Lunch", price: 20, date: transfer.date, category: .others, walletID: ledger.defaultWalletID)
        ledger.transactions = [stale, ordinary, stale]

        try ledger.prepareForWrite()
        try ledger.prepareForWrite()

        let expected = Expense(
            id: feeID, title: "Transfer fee", price: 2_500, date: transfer.date,
            category: .feesInterest, walletID: transfer.fromWalletID
        )
        XCTAssertEqual(ledger.transactions, [ordinary, expected])
    }

    func testPrepareForWriteRejectsInvalidTransfers() {
        var ledger = TestFixtures.ledger()
        var transfer = TestFixtures.transfer(in: ledger)
        transfer.feeExpenseID = UUID()
        var sameWallet = transfer
        sameWallet.toWalletID = sameWallet.fromWalletID
        var missingWallet = transfer
        missingWallet.toWalletID = UUID()
        var zeroAmount = transfer
        zeroAmount.amount = 0
        var negativeFee = transfer
        negativeFee.feeAmount = -1

        for invalid in [sameWallet, missingWallet, zeroAmount, negativeFee] {
            ledger.transfers = [invalid]
            XCTAssertThrowsError(try ledger.prepareForWrite()) { error in
                XCTAssertEqual(error as? WalletError, .invalidAmount)
            }
        }
    }
}
