import XCTest
@testable import Inpenso

final class WalletIntegrationTests: XCTestCase {
    private var ledger = TestFixtures.ledger()

    override func setUpWithError() throws {
        try super.setUpWithError()
        guard StorageService.isUnitTestHost else {
            throw IsolationError.testHostRequired
        }
        ledger = TestFixtures.ledger()
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        addTeardownBlock {
            StorageService.testLedgerURL = nil
            try FileManager.default.removeItem(at: directory)
        }
        let ledgerURL = directory.appendingPathComponent("transactions.json")
        try JSONEncoder().encode(ledger).write(to: ledgerURL, options: .atomic)
        StorageService.testLedgerURL = ledgerURL
    }

    private enum IsolationError: Error {
        case testHostRequired
    }

    func testBalancesIncludeTransferAndFeeOnTheirDate() throws {
        let transfer = TestFixtures.transfer(in: ledger)
        try WalletService.saveTransfer(transfer)
        XCTAssertEqual(
            WalletService.balances(asOf: TestFixtures.date(2_025, 1, 31)),
            [transfer.fromWalletID: 1_000_000, transfer.toWalletID: 0]
        )
        XCTAssertEqual(
            WalletService.balances(asOf: transfer.date),
            [transfer.fromWalletID: 797_500, transfer.toWalletID: 200_000]
        )
    }

    func testLastActiveWalletCannotBeArchived() throws {
        let bank = ledger.defaultWalletID
        let cash = ledger.wallets[1].id
        try WalletService.archiveWallet(cash, replacementDefault: nil)
        XCTAssertThrowsError(try WalletService.archiveWallet(bank, replacementDefault: cash)) { error in
            XCTAssertEqual(error as? WalletError, .lastActiveWallet)
        }
        XCTAssertEqual(WalletService.defaultWalletID(), bank)
        XCTAssertEqual(WalletService.loadWallets().filter { !$0.isArchived }.map(\.id), [bank])
    }

    func testUnarchivingPersistsActiveWallet() throws {
        let cash = ledger.wallets[1].id
        try WalletService.archiveWallet(cash, replacementDefault: nil)
        XCTAssertEqual(WalletService.loadWallets().first { $0.id == cash }?.isArchived, true)
        try WalletService.unarchiveWallet(cash)
        XCTAssertEqual(WalletService.loadWallets().first { $0.id == cash }?.isArchived, false)
    }

    @MainActor
    func testAddingExpenseToArchivedWalletThrows() throws {
        let cash = ledger.wallets[1].id
        try WalletService.archiveWallet(cash, replacementDefault: nil)
        let viewModel = ExpenseViewModel()
        XCTAssertThrowsError(try viewModel.addExpense(
            title: "Lunch", price: 30_000, date: TestFixtures.date(2_025, 2, 1), category: .others, walletID: cash
        )) { error in
            XCTAssertEqual(error as? WalletError, .unknownWallet)
        }
        XCTAssertEqual(StorageService.loadLedger()?.transactions, [])
    }

    @MainActor
    func testTransferFeeCannotBeEditedOrRemovedAsExpense() throws {
        try WalletService.saveTransfer(TestFixtures.transfer(in: ledger))
        let feeID = try XCTUnwrap(WalletService.loadTransfers().first?.feeExpenseID)
        let viewModel = ExpenseViewModel()
        let fee = try XCTUnwrap(viewModel.expenses.first { $0.id == feeID })
        XCTAssertTrue(viewModel.isTransferFee(fee))
        viewModel.updateExpense(id: feeID) { _ in
            XCTFail("The update closure must never run for a transfer fee.")
        }
        XCTAssertNil(viewModel.removeExpense(id: feeID))
        XCTAssertEqual(StorageService.loadLedger()?.transactions, [fee])
    }

    func testPostingTwiceToArchivedRuleWalletUsesDefaultOnce() throws {
        let cash = ledger.wallets[1].id
        try WalletService.archiveWallet(cash, replacementDefault: nil)
        let date = TestFixtures.date(2_025, 2, 1)
        let rule = TestFixtures.rule(startDate: date, day: 1, walletID: cash)
        let first = RecurringService.dueOccurrences(rules: [rule], postedIDs: [], now: date, calendar: TestFixtures.calendar)
        let second = RecurringService.dueOccurrences(rules: [rule], postedIDs: [], now: date, calendar: TestFixtures.calendar)
        let occurrence = try XCTUnwrap(first.first)
        XCTAssertEqual(second.map(\.id), [occurrence.id])

        try RecurringService.post(first)
        try RecurringService.post(second)

        let transactions = try XCTUnwrap(StorageService.loadLedger()).transactions
        XCTAssertEqual(transactions.map(\.id), [occurrence.id])
        XCTAssertEqual(transactions.first?.walletID, ledger.defaultWalletID)
        XCTAssertEqual(transactions.first?.price, rule.amount)
        XCTAssertEqual(transactions.first?.date, date)
    }

    func testVersionOneBackupWithoutWalletFieldsImports() throws {
        let data = Data("""
        {
          "formatVersion": 1,
          "exportedAt": "2025-02-01T00:00:00Z",
          "currencyCode": "IDR",
          "transactions": [{"title": "Lunch", "price": 25000, "date": "2025-02-01T00:00:00Z"}],
          "budgets": {"02-2025": 300000}
        }
        """.utf8)
        let decoded = try BackupService.readBackup(from: data, currentCurrencyCode: "USD")
        XCTAssertFalse(decoded.isLegacy)
        XCTAssertEqual(decoded.backup.formatVersion, 1)
        XCTAssertEqual(decoded.backup.currencyCode, "IDR")
        XCTAssertEqual(decoded.backup.transactions.map(\.price), [25_000])
        XCTAssertEqual(decoded.backup.budgets, ["02-2025": 300_000])
        XCTAssertNil(decoded.backup.wallets)

        let cash = ledger.wallets[1].id
        XCTAssertEqual(try BackupService.restore(decoded.backup, mode: .merge, importWalletID: cash), "IDR")
        let imported = try XCTUnwrap(StorageService.loadLedger()?.transactions.first)
        XCTAssertEqual(imported.walletID, cash)
        XCTAssertEqual(imported.price, 25_000)
    }

    func testBareArrayImportsWithCurrentCurrencyAndLegacyDateEncoding() throws {
        let data = Data("""
        [{"title": "Lunch", "price": 25, "date": 0}]
        """.utf8)
        let decoded = try BackupService.readBackup(from: data, currentCurrencyCode: "IDR")
        XCTAssertTrue(decoded.isLegacy)
        XCTAssertEqual(decoded.backup.formatVersion, 0)
        XCTAssertEqual(decoded.backup.currencyCode, "IDR")
        XCTAssertEqual(decoded.backup.transactions.map(\.title), ["Lunch"])
        XCTAssertEqual(decoded.backup.transactions.map(\.date), [TestFixtures.date(2_001, 1, 1)])

        XCTAssertEqual(try BackupService.restore(decoded.backup, mode: .merge), "IDR")
        let imported = try XCTUnwrap(StorageService.loadLedger()?.transactions.first)
        XCTAssertEqual(imported.walletID, ledger.defaultWalletID)
        XCTAssertEqual(imported.title, "Lunch")
    }
}
