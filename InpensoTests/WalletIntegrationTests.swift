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

    func testSetCurrentBalanceBackSolvesOpeningBalance() throws {
        let transfer = TestFixtures.transfer(in: ledger)
        try WalletService.saveTransfer(transfer)
        let asOf = transfer.date
        let before = try XCTUnwrap(WalletService.balances(asOf: asOf)[transfer.fromWalletID])
        let opening = try XCTUnwrap(WalletService.loadWallets().first { $0.id == transfer.fromWalletID }).openingBalance

        try WalletService.setCurrentBalance(transfer.fromWalletID, to: 5_000_000, asOf: asOf)

        XCTAssertEqual(WalletService.balances(asOf: asOf)[transfer.fromWalletID], 5_000_000)
        XCTAssertEqual(WalletService.balances(asOf: asOf)[transfer.toWalletID], 200_000)
        let wallet = try XCTUnwrap(WalletService.loadWallets().first { $0.id == transfer.fromWalletID })
        XCTAssertEqual(wallet.openingBalance, opening + 5_000_000 - before)
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

extension WalletIntegrationTests {
    private func saveCard(balance: Double = 0, limit: Double? = nil) throws -> Wallet {
        let card = Wallet(
            name: "Credit Card", kind: .credit, iconName: "creditcard.fill", colorHex: "#34785D",
            openingBalance: balance, creditLimit: limit, statementDay: 25, dueDay: 31
        )
        try WalletService.saveWallet(card)
        return card
    }

    @MainActor
    func testCreditTotalsAndLimit() throws {
        let card = try saveCard(balance: -600_000, limit: 500_000)
        try WalletService.setCurrentBalance(ledger.wallets[1].id, to: -100)
        let wallets = WalletsViewModel()
        XCTAssertEqual(wallets.assetsTotal, 1_000_000)
        XCTAssertEqual(wallets.owedTotal, 600_000)
        XCTAssertEqual(wallets.netTotal, 400_000)
        XCTAssertEqual(wallets.available(for: card), -100_000)
        XCTAssertTrue(wallets.isOverLimit(card))
        try wallets.setAmountOwed(100_000, for: card)
        XCTAssertEqual(wallets.balance(of: card), -100_000)
        XCTAssertEqual(wallets.available(for: card), 400_000)
        XCTAssertFalse(wallets.isOverLimit(card))
    }

    @MainActor
    func testCreditPurchaseAndCumulativeRepayments() throws {
        let card = try saveCard()
        let expenses = ExpenseViewModel()
        let purchase = Expense(
            title: "Laptop dock", price: 2_695_000, date: TestFixtures.date(2_025, 8, 25),
            category: .shopping, walletID: card.id
        )
        try expenses.addCreditPurchase(purchase, instalment: (12, 0, ledger.defaultWalletID))
        let wallets = WalletsViewModel()
        let plan = try XCTUnwrap(wallets.instalmentPlans.first)
        XCTAssertEqual(wallets.owed(for: card), 2_695_000)
        XCTAssertEqual(expenses.expenses.map(\.id), [purchase.id])
        XCTAssertEqual(plan.monthlyAmount, 224_583.33, accuracy: 0.01)

        let first = TestFixtures.date(2_025, 10, 1)
        let second = TestFixtures.date(2_025, 10, 31)
        try wallets.payInstalment(plan, amount: 284_583, from: ledger.defaultWalletID, date: first)
        XCTAssertEqual(wallets.progress(of: plan).paidCount, 1)
        try wallets.payInstalment(plan, amount: 164_583, from: ledger.defaultWalletID, date: second)
        XCTAssertEqual(wallets.progress(of: plan).paidCount, 2)
        XCTAssertEqual(wallets.progress(of: plan).remainingPrincipal, 2_245_834)
        XCTAssertEqual(wallets.owed(for: card), 2_245_834)

        try wallets.payInstalment(plan, amount: 2_245_833.50, from: ledger.defaultWalletID, date: second)
        XCTAssertEqual(wallets.progress(of: plan).paidCount, 12)
        XCTAssertEqual(wallets.progress(of: plan).remainingPrincipal, 0)
        XCTAssertTrue(wallets.progress(of: plan).isFinished)
        XCTAssertNil(wallets.progress(of: plan).nextDueDate)
        XCTAssertEqual(wallets.owed(for: card), 0)
    }

    @MainActor
    func testGenericPaymentsCoverThreeInstalments() throws {
        let card = try saveCard()
        let plan = InstalmentPlan(
            creditWalletID: card.id, principal: 2_695_000, months: 12,
            monthlyAmount: 224_583.33, monthlyFee: 0, firstDueDate: TestFixtures.date(2_026, 8, 25),
            title: "Laptop dock"
        )
        try StorageService.updateLedger { $0.instalmentPlans = [plan] }
        let dates = [
            TestFixtures.date(2_026, 9, 25),
            TestFixtures.date(2_026, 10, 1),
            TestFixtures.date(2_026, 10, 31),
        ]
        for (date, amount) in zip(dates, [224_583.0, 284_583, 164_583]) {
            try WalletService.saveTransfer(Transfer(
                fromWalletID: ledger.defaultWalletID, toWalletID: card.id, amount: amount, date: date
            ))
        }
        let wallets = WalletsViewModel()
        XCTAssertEqual(wallets.progress(of: plan, asOf: dates[1]).paidCount, 2)
        let progress = wallets.progress(of: plan, asOf: dates[2])
        XCTAssertEqual(progress.paidCount, 3)
        XCTAssertEqual(progress.remainingPrincipal, 2_021_250, accuracy: 1)
        XCTAssertEqual(progress.nextDueDate, plan.dueDate(at: 3))
        XCTAssertTrue(wallets.upcomingDues(from: dates[2]).isEmpty)
    }

    @MainActor
    func testGenericPaymentPaysOlderOrdinaryBillBeforeInstalment() throws {
        let card = try saveCard()
        let day = TestFixtures.date(2_025, 2, 2)
        let due = TestFixtures.date(2_025, 2, 3)
        let plan = InstalmentPlan(
            creditWalletID: card.id, principal: 200, months: 2, monthlyAmount: 100, monthlyFee: 0,
            firstDueDate: due, title: "Plan"
        )
        try StorageService.updateLedger {
            $0.instalmentPlans = [plan]
            $0.transactions.append(Expense(title: "Older purchase", price: 70, date: day, category: .shopping, walletID: card.id))
            $0.transactions.append(Expense(title: "Newer purchase", price: 50, date: due.addingTimeInterval(3_600),
                                           category: .shopping, walletID: card.id))
        }
        try WalletService.saveTransfer(Transfer(
            fromWalletID: ledger.defaultWalletID, toWalletID: card.id, amount: 150, date: due
        ))
        let wallets = WalletsViewModel()
        XCTAssertEqual(wallets.progress(of: plan, asOf: due).paidCount, 0)
        XCTAssertEqual(wallets.progress(of: plan, asOf: due).remainingPrincipal, 120)
        XCTAssertEqual(wallets.upcomingDues(from: due.addingTimeInterval(7_200)).first?.amount, 20)
    }

    @MainActor
    func testLinkedTransferGenericTransferAndRefundEachCountOnce() throws {
        let card = try saveCard()
        let due = TestFixtures.date(2_025, 2, 3)
        let plan = InstalmentPlan(
            creditWalletID: card.id, principal: 200, months: 2, monthlyAmount: 100, monthlyFee: 0,
            firstDueDate: due, title: "Plan"
        )
        try StorageService.updateLedger { $0.instalmentPlans = [plan] }
        try WalletService.payInstalment(plan, amount: 60, from: ledger.defaultWalletID, date: due)
        try WalletService.saveTransfer(Transfer(
            fromWalletID: ledger.defaultWalletID, toWalletID: card.id, amount: 40, date: due
        ))
        let wallets = WalletsViewModel()
        XCTAssertEqual(wallets.progress(of: plan, asOf: due).paidCount, 1)
        XCTAssertEqual(wallets.progress(of: plan, asOf: due).remainingPrincipal, 100)

        try StorageService.updateLedger {
            $0.transactions.append(Expense(
                title: "Refund", price: 100, date: due, category: .shopping, type: .refund, walletID: card.id
            ))
        }
        wallets.refresh()
        XCTAssertTrue(wallets.progress(of: plan, asOf: due).isFinished)
        XCTAssertTrue(wallets.upcomingDues(within: 60, from: due).isEmpty)
    }

    @MainActor
    func testInstalmentPaymentFeeAndBackupCompatibility() throws {
        let card = try saveCard()
        let date = TestFixtures.date(2_025, 1, 25)
        let viewModel = ExpenseViewModel()
        try viewModel.addCreditPurchase(
            Expense(title: "Phone", price: 600_000, date: date, category: .shopping, walletID: card.id),
            instalment: (3, 1_000, ledger.defaultWalletID)
        )
        let plan = try XCTUnwrap(StorageService.loadLedger()?.instalmentPlans?.first)
        let calendar = Calendar.current
        XCTAssertEqual(calendar.component(.day, from: plan.firstDueDate), 28)
        XCTAssertEqual(plan.dueDate(at: 1).map { calendar.component(.day, from: $0) }, 31)
        try viewModel.payInstalment(plan, amount: 200_000, from: ledger.defaultWalletID, date: date)
        let fee = try XCTUnwrap(viewModel.expenses.first { viewModel.isTransferFee($0) })
        XCTAssertEqual(fee.categoryID, "builtin-feesInterest")
        XCTAssertEqual(fee.price, 1_000)

        let backup = try BackupService.makeBackup()
        XCTAssertEqual(backup.formatVersion, 4)
        let data = try BackupService.encode(backup)
        let (decoded, _) = try BackupService.readBackup(from: data, currentCurrencyCode: "IDR")
        try StorageService.clearExpenses()
        try BackupService.restore(decoded, mode: .merge)
        try BackupService.restore(decoded, mode: .merge)
        XCTAssertEqual(StorageService.loadLedger()?.instalmentPlans?.map(\.id), [plan.id])
        XCTAssertEqual(StorageService.loadLedger()?.transfers.map(\.instalmentPlanID), [plan.id])
        try BackupService.restore(decoded, mode: .replace)
        XCTAssertEqual(StorageService.loadLedger()?.instalmentPlans?.map(\.id), [plan.id])

        var older = backup
        older.formatVersion = 3
        older.instalmentPlans = nil
        older.transfers?[0].instalmentPlanID = nil
        let olderData = try BackupService.encode(older)
        let (olderDecoded, _) = try BackupService.readBackup(from: olderData, currentCurrencyCode: "IDR")
        try BackupService.restore(olderDecoded, mode: .replace)
        XCTAssertNil(StorageService.loadLedger()?.instalmentPlans)
        XCTAssertEqual(StorageService.loadLedger()?.transfers.count, 1)
        try BackupService.restore(decoded, mode: .merge)
        XCTAssertEqual(StorageService.loadLedger()?.transfers.map(\.instalmentPlanID), [plan.id])
    }

    @MainActor
    func testUpcomingDuesKeepFutureStatementPurchasesOutOfTheBill() throws {
        let card = try saveCard()
        let calendar = Calendar.current
        let statementDay = try XCTUnwrap(creditDate(day: 25, inMonthOf: TestFixtures.date(2_025, 2, 15)))
        let asOf = try XCTUnwrap(calendar.date(byAdding: .day, value: 2, to: statementDay))
        let afterStatement = try XCTUnwrap(calendar.date(byAdding: .day, value: 1, to: statementDay))
        let expenses = ExpenseViewModel()
        for (date, price) in [(statementDay, 100_000.0), (afterStatement, 50_000)] {
            try expenses.addCreditPurchase(
                Expense(title: "Card purchase", price: price, date: date, category: .shopping, walletID: card.id),
                instalment: nil
            )
        }
        try WalletService.saveTransfer(Transfer(
            fromWalletID: ledger.defaultWalletID, toWalletID: card.id, amount: 25_000, date: asOf
        ))
        let viewModel = WalletsViewModel()
        let due = try XCTUnwrap(viewModel.upcomingDues(from: asOf).first)
        XCTAssertEqual(due.amount, 75_000)
        XCTAssertEqual(calendar.component(.day, from: due.dueDate), 28)
        XCTAssertEqual(viewModel.owed(for: card), 125_000)
    }

    func testInvalidInstalmentPlansAreRejected() throws {
        let card = try saveCard()
        var candidate = try XCTUnwrap(StorageService.loadLedger())
        let valid = InstalmentPlan(
            creditWalletID: card.id, principal: 1_000, months: 2, monthlyAmount: 500,
            monthlyFee: 0, firstDueDate: .now, title: "Plan"
        )
        let invalidEdits: [(inout InstalmentPlan) -> Void] = [
            { $0.creditWalletID = UUID() },
            { $0.creditWalletID = self.ledger.defaultWalletID },
            { $0.payFromWalletID = UUID() },
            { $0.months = 0 },
            { $0.principal = -.infinity },
            { $0.monthlyAmount = -.ulpOfOne },
            { $0.monthlyFee = .nan },
        ]
        for edit in invalidEdits {
            var invalid = valid
            edit(&invalid)
            candidate.instalmentPlans = [invalid]
            XCTAssertThrowsError(try candidate.prepareForWrite())
        }
        candidate.instalmentPlans = [valid]
        XCTAssertNoThrow(try candidate.prepareForWrite())
    }
}
