//
//  StorageService.swift
//  iExpense
//
//  Created by Dragomir Mindrescu on 27.04.2025.
//

import Darwin
import Foundation
import OSLog

extension Notification.Name {
    static let inpensoDataDidChange = Notification.Name("InpensoDataDidChange")
}

struct WalletLedger: Codable {
    static let currentVersion = 1

    var version = Self.currentVersion
    var wallets: [Wallet]
    var defaultWalletID: UUID
    var transactions: [Expense]
    var transfers: [Transfer]
    var currency: String
    var instalmentPlans: [InstalmentPlan]?

    static func initial(transactions: [Expense], currency: String) -> Self {
        let cash = Wallet(name: "Cash", kind: .cash, iconName: WalletKind.cash.defaultIconName, colorHex: "#34785D")
        return Self(wallets: [cash], defaultWalletID: cash.id, transactions: transactions, transfers: [], currency: currency)
    }

    var hasActivity: Bool { !transactions.isEmpty || !transfers.isEmpty || !(instalmentPlans ?? []).isEmpty }

    mutating func prepareForWrite() throws {
        let walletsByID = Dictionary(wallets.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        guard walletsByID.count == wallets.count,
              wallets.contains(where: { $0.id == defaultWalletID && !$0.isArchived }),
              Set(transfers.map(\.id)).count == transfers.count
        else { throw WalletError.storageFailure }

        let plansByID = try validateCreditData(walletsByID: walletsByID)
        try normalizeTransactions(walletsByID: walletsByID)
        let feeIDs = try validateTransfers(walletsByID: walletsByID, plansByID: plansByID)
        rebuildTransferFees(replacing: feeIDs)
    }

    /// Fills missing wallets, normalizes category IDs and checks each transaction's wallet exists.
    private mutating func normalizeTransactions(walletsByID: [UUID: Wallet]) throws {
        for index in transactions.indices {
            if transactions[index].walletID == nil { transactions[index].walletID = defaultWalletID }
            let categoryID = Category.normalizedCategoryID(transactions[index].categoryID, for: transactions[index].type)
            if categoryID != transactions[index].categoryID, let category = Category.category(from: categoryID) {
                transactions[index].categoryID = categoryID
                transactions[index].category = category
            }
            if transactions[index].type != .refund { transactions[index].refundOfID = nil }
            guard let id = transactions[index].walletID, walletsByID[id] != nil else { throw WalletError.unknownWallet }
        }
    }

    private func validateCreditData(walletsByID: [UUID: Wallet]) throws -> [UUID: InstalmentPlan] {
        for wallet in wallets {
            guard wallet.creditLimit.map({ $0.isFinite && $0 >= 0 }) ?? true,
                  wallet.statementDay.map({ (1...31).contains($0) }) ?? true,
                  wallet.dueDay.map({ (1...31).contains($0) }) ?? true
            else { throw WalletError.invalidAmount }
        }
        var plansByID: [UUID: InstalmentPlan] = [:]
        for plan in instalmentPlans ?? [] {
            guard walletsByID[plan.creditWalletID]?.kind.isCredit == true,
                  plan.payFromWalletID.map({ walletsByID[$0] != nil && $0 != plan.creditWalletID }) ?? true
            else { throw WalletError.unknownWallet }
            guard plan.months >= 1,
                  plan.scheduledDay.map({ (1...31).contains($0) }) ?? true,
                  [plan.principal, plan.monthlyAmount, plan.monthlyFee].allSatisfy({ $0.isFinite && $0 >= 0 }),
                  plansByID.updateValue(plan, forKey: plan.id) == nil
            else { throw WalletError.invalidAmount }
        }
        return plansByID
    }

    /// Checks every transfer and returns the IDs of their fee transactions.
    private func validateTransfers(
        walletsByID: [UUID: Wallet], plansByID: [UUID: InstalmentPlan]
    ) throws -> Set<UUID> {
        var feeIDs = Set<UUID>()
        for transfer in transfers {
            guard transfer.fromWalletID != transfer.toWalletID,
                  let source = walletsByID[transfer.fromWalletID], let destination = walletsByID[transfer.toWalletID],
                  source.openingDate.map({ $0 <= transfer.date }) ?? true,
                  destination.openingDate.map({ $0 <= transfer.date }) ?? true,
                  transfer.amount.isFinite, transfer.amount > 0,
                  (transfer.feeAmount ?? 0).isFinite, (transfer.feeAmount ?? 0) >= 0
            else { throw WalletError.invalidAmount }
            if let planID = transfer.instalmentPlanID {
                guard plansByID[planID]?.creditWalletID == transfer.toWalletID else { throw WalletError.unknownWallet }
            }
            if (transfer.feeAmount ?? 0) > 0 {
                guard let id = transfer.feeExpenseID, feeIDs.insert(id).inserted else { throw WalletError.storageFailure }
            } else if transfer.feeExpenseID != nil {
                throw WalletError.storageFailure
            }
        }
        return feeIDs
    }

    /// Replaces stored fee transactions with ones derived from the transfers.
    private mutating func rebuildTransferFees(replacing feeIDs: Set<UUID>) {
        transactions.removeAll { feeIDs.contains($0.id) }
        for transfer in transfers {
            guard let id = transfer.feeExpenseID, let fee = transfer.feeAmount else { continue }
            transactions.append(Expense(
                id: id, title: "Transfer fee", price: fee, date: transfer.date, category: .feesInterest,
                walletID: transfer.fromWalletID
            ))
        }
    }
}

struct StorageService {
    /// From Info.plist `AppGroupIdentifier`, set by INPENSO_APP_GROUP in Config/Signing.xcconfig.
    static let appGroupID = Bundle.main.object(forInfoDictionaryKey: "AppGroupIdentifier") as? String
        ?? "group.com.vintuss.Inpenso"

    /// App-group defaults shared with the widget. Nil in the unit-test host so tests never touch real data.
    static var sharedDefaults: UserDefaults? { userDefaults }

    private static var userDefaults: UserDefaults? {
        #if DEBUG
        if isUnitTestHost { return nil }
        #endif
        return UserDefaults(suiteName: appGroupID)
    }

    private static let expensesKey = "expenses"
    private static let budgetsKey = "budgets"
    private static let categoryCatalogStateKey = "categoryCatalogState"
    private static let customCategoriesKey = "customCategories"

    private static let logger = Logger(subsystem: "com.vintuss.Inpenso", category: "TransactionStorage")

    #if DEBUG
    static let isUnitTestHost = ProcessInfo.processInfo.environment["INPENSO_UNIT_TESTS"] == "1"
    static var testLedgerURL: URL?
    #endif

    private static var expensesURL: URL? {
        #if DEBUG
        if isUnitTestHost { return testLedgerURL }
        #endif
        return FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID)?
            .appendingPathComponent("transactions.json")
    }

    static func saveExpenses(_ expenses: [Expense]) {
        updateExpenses { $0 = expenses }
    }

    static func loadExpenses() -> [Expense] {
        if let ledger = loadLedger() { return ledger.transactions }
        if expensesURL == nil { return (try? readLegacyExpenses()) ?? [] }
        return []
    }

    static func loadLedger() -> WalletLedger? {
        do {
            guard let url = expensesURL else { throw WalletError.storageFailure }
            if let ledger = try readLedger(at: url) { return ledger }
            return try updateLedger { $0 }
        } catch {
            logger.error("Unable to load ledger: \(error.localizedDescription)")
            return nil
        }
    }

    private struct LedgerVersion: Decodable { let version: Int }

    private static func readLedger(at url: URL) throws -> WalletLedger? {
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch let error as CocoaError where error.code == .fileReadNoSuchFile {
            return nil
        }
        // A JSON object is always an envelope. Let invalid and newer envelopes fail closed.
        if data.first(where: { ![9, 10, 13, 32].contains($0) }) == 123 {
            guard try JSONDecoder().decode(LedgerVersion.self, from: data).version == WalletLedger.currentVersion
            else { throw WalletError.storageFailure }
            return try JSONDecoder().decode(WalletLedger.self, from: data)
        }
        return nil
    }

    private static func readOrMigrateLedger(at url: URL) throws -> WalletLedger {
        if let ledger = try readLedger(at: url) { return ledger }
        let transactions: [Expense]
        do {
            transactions = try JSONDecoder().decode([Expense].self, from: Data(contentsOf: url))
        } catch let error as CocoaError where error.code == .fileReadNoSuchFile {
            transactions = try readLegacyExpenses()
        }
        var ledger = WalletLedger.initial(
            transactions: transactions,
            currency: userDefaults?.string(forKey: "selectedCurrency")
                ?? UserDefaults.standard.string(forKey: "selectedCurrency") ?? "USD"
        )
        try ledger.prepareForWrite()
        try write(ledger, to: url)
        return ledger
    }

    private static func readLegacyExpenses() throws -> [Expense] {
        guard let data = userDefaults?.data(forKey: expensesKey) else { return [] }
        var expenses = try JSONDecoder().decode([Expense].self, from: data)
        for index in expenses.indices {
            if expenses[index].categoryID.isEmpty {
                expenses[index].categoryID = expenses[index].category.categoryID
            }
            if expenses[index].notes == nil {
                let key = "notes_\(expenses[index].id.uuidString)"
                if let notes = UserDefaults.standard.string(forKey: key), !notes.isEmpty {
                    expenses[index].notes = notes
                }
            }
        }
        return expenses
    }

    private static func lockedDescriptor(at url: URL) throws -> Int32 {
        let descriptor = open(url.path + ".lock", O_CREAT | O_RDWR, 0o600)
        guard descriptor >= 0 else { throw WalletError.storageFailure }
        var status: Int32
        repeat {
            status = flock(descriptor, LOCK_EX)
        } while status == -1 && errno == EINTR
        guard status == 0 else {
            close(descriptor)
            throw WalletError.storageFailure
        }
        return descriptor
    }

    private static func write(_ ledger: WalletLedger, to url: URL) throws {
        // The lock lives on a separate inode and survives atomic JSON replacement.
        try JSONEncoder().encode(ledger).write(to: url, options: .atomic)
    }

    @discardableResult
    static func updateLedger<T>(_ body: (inout WalletLedger) throws -> T) throws -> T {
        guard let url = expensesURL else { throw WalletError.storageFailure }
        let descriptor = try lockedDescriptor(at: url)
        defer { close(descriptor) }
        var ledger = try readOrMigrateLedger(at: url)
        let result = try body(&ledger)
        try ledger.prepareForWrite()
        try write(ledger, to: url)
        return result
    }

    @discardableResult
    static func updateExpenses<T>(_ body: (inout [Expense]) throws -> T) rethrows -> T {
        guard let url = expensesURL, let descriptor = try? lockedDescriptor(at: url) else {
            logger.error("Unable to lock transaction storage")
            var snapshot: [Expense] = []
            return try body(&snapshot)
        }
        defer { close(descriptor) }

        guard var ledger = try? readOrMigrateLedger(at: url) else {
            logger.error("Unable to read transaction storage")
            var snapshot: [Expense] = []
            return try body(&snapshot)
        }

        let result = try body(&ledger.transactions)
        do {
            try ledger.prepareForWrite()
            try write(ledger, to: url)
        } catch {
            logger.error("Unable to save transactions: \(error.localizedDescription)")
        }
        return result
    }

    static func saveBudgets(_ budgets: [String: Double]) {
        guard let userDefaults = userDefaults else { return }
        do {
            let data = try JSONEncoder().encode(budgets)
            userDefaults.set(data, forKey: budgetsKey)
        } catch {
            // Error handling without print
        }
    }

    /// Budget for a month: its own value, else the most recent earlier month's ("MM-yyyy" keys),
    /// so a budget keeps applying until the user sets a new one.
    static func effectiveBudget(month: Int, year: Int, in budgets: [String: Double]) -> Double {
        if let own = budgets[String(format: "%02d-%d", month, year)] { return own }
        let target = year * 12 + month
        var best: (index: Int, amount: Double)?
        for (key, amount) in budgets {
            let parts = key.split(separator: "-")
            guard parts.count == 2, let m = Int(parts[0]), let y = Int(parts[1]) else { continue }
            let index = y * 12 + m
            if index < target, best == nil || index > best!.index {
                best = (index, amount)
            }
        }
        return best?.amount ?? 0
    }

    static func loadBudgets() -> [String: Double] {
        guard let userDefaults = userDefaults,
              let data = userDefaults.data(forKey: budgetsKey) else {
            return [:]
        }
        do {
            let budgets = try JSONDecoder().decode([String: Double].self, from: data)
            return budgets
        } catch {
            // Error handling without print
            return [:]
        }
    }

    static func clearExpenses() throws {
        try updateLedger {
            $0.transactions.removeAll()
            $0.transfers.removeAll()
            $0.instalmentPlans = nil
        }
    }

    static func saveCustomCategories(_ categories: [FinanceCategory]) {
        guard let userDefaults = userDefaults else { return }
        do {
            let data = try JSONEncoder().encode(categories)
            userDefaults.set(data, forKey: customCategoriesKey)
        } catch {
            // Error handling without print
        }
    }

    static func loadCustomCategories() -> [FinanceCategory] {
        guard let userDefaults = userDefaults,
              let data = userDefaults.data(forKey: customCategoriesKey) else {
            return []
        }

        do {
            return try JSONDecoder().decode([FinanceCategory].self, from: data)
        } catch {
            return []
        }
    }

    static func saveCategoryCatalogState(_ state: CategoryCatalogState) {
        guard let userDefaults = userDefaults else { return }
        do {
            let data = try JSONEncoder().encode(state)
            userDefaults.set(data, forKey: categoryCatalogStateKey)
        } catch {
            // Error handling without print
        }
    }

    static func loadCategoryCatalogState() -> CategoryCatalogState? {
        guard let userDefaults = userDefaults,
              let data = userDefaults.data(forKey: categoryCatalogStateKey) else {
            return nil
        }

        do {
            return try JSONDecoder().decode(CategoryCatalogState.self, from: data)
        } catch {
            return nil
        }
    }
}
