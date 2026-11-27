import XCTest
@testable import Inpenso

final class ExportTests: XCTestCase {
    func testCurrentBackupRoundTrip() throws {
        var ledger = TestFixtures.ledger()
        var transfer = TestFixtures.transfer(in: ledger)
        transfer.feeExpenseID = UUID()
        ledger.transfers = [transfer]
        try ledger.prepareForWrite()
        let rule = TestFixtures.rule(startDate: transfer.date, day: 1)
        let backup = InpensoBackup(
            formatVersion: InpensoBackup.currentFormatVersion, exportedAt: transfer.date, appVersion: "1.0",
            currencyCode: ledger.currency, transactions: ledger.transactions, budgets: ["02-2025": 300_000],
            categoryCatalog: nil, recurringRules: [rule], categoryBudgets: ["others": 20_000],
            wallets: ledger.wallets, transfers: ledger.transfers, defaultWalletID: ledger.defaultWalletID
        )
        let decoded = try BackupService.readBackup(from: BackupService.encode(backup), currentCurrencyCode: "USD")
        XCTAssertFalse(decoded.isLegacy)
        XCTAssertEqual(decoded.backup.formatVersion, InpensoBackup.currentFormatVersion)
        XCTAssertEqual(decoded.backup.exportedAt, backup.exportedAt)
        XCTAssertEqual(decoded.backup.currencyCode, "IDR")
        XCTAssertEqual(decoded.backup.transactions, backup.transactions)
        XCTAssertEqual(decoded.backup.budgets, backup.budgets)
        XCTAssertEqual(decoded.backup.recurringRules, backup.recurringRules)
        XCTAssertEqual(decoded.backup.categoryBudgets, backup.categoryBudgets)
        XCTAssertEqual(decoded.backup.wallets, ledger.wallets)
        XCTAssertEqual(decoded.backup.transfers, [transfer])
        XCTAssertEqual(decoded.backup.defaultWalletID, ledger.defaultWalletID)
    }

    func testCSVQuotesCommasQuotesAndNewlines() {
        let expense = Expense(
            title: "Lunch, \"special\"", price: 12.5, date: TestFixtures.date(2_025, 2, 1),
            category: .others, notes: "First\r\nSecond"
        )
        let csv = CSVExportService.render(transactions: [expense], currencyCode: "USD", timeZone: TestFixtures.calendar.timeZone) { _ in
            "Food, dining"
        }
        let header = "date,type,title,category,amount,currency,notes,wallet,from_wallet,to_wallet,fee"
        let record = "2025-02-01,expense,\"Lunch, \"\"special\"\"\",\"Food, dining\",12.5,USD,\"First\r\nSecond\",,,,"
        XCTAssertEqual(csv, header + "\r\n" + record + "\r\n")
    }
}
