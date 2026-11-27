//
//  BackupService.swift
//  iExpense
//

import Foundation

/// A full, versioned snapshot of the user's data.
struct InpensoBackup: Codable {
    static let currentFormatVersion = 2

    var formatVersion: Int
    var exportedAt: Date
    var appVersion: String?
    /// Currency the amounts were recorded in. Amounts carry no per-row currency.
    var currencyCode: String
    var transactions: [Expense]
    var budgets: [String: Double]
    var categoryCatalog: CategoryCatalogState?
    // Added after format 1 shipped; optional so older files still decode.
    var recurringRules: [RecurringRule]?
    var categoryBudgets: [String: Double]?
    var wallets: [Wallet]?
    var transfers: [Transfer]?
    var defaultWalletID: UUID?
}

enum RestoreMode {
    /// Keep current data; add transactions, budgets and custom categories that are not present yet.
    case merge
    /// Replace all transactions, budgets, categories and the currency with the backup's.
    case replace
}

struct RestorePreview {
    let backup: InpensoBackup
    /// True when the file is the old expenses-only export.
    let isLegacyFormat: Bool
    let newTransactionCount: Int
    let duplicateTransactionCount: Int
    let newBudgetCount: Int
    let newCustomCategoryCount: Int
    let currentCurrencyCode: String

    var newWalletCount = 0
    var newTransferCount = 0
    var totalTransactionCount: Int { backup.transactions.count }
    var currencyDiffers: Bool { !isLegacyFormat && backup.currencyCode != currentCurrencyCode }
}

enum BackupError: LocalizedError {
    case unreadableFile
    case unsupportedVersion(Int)
    case currencyMismatch

    var errorDescription: String? {
        switch self {
        case .unreadableFile:
            return "This file isn't an Inpenso backup."
        case .currencyMismatch:
            return "This backup uses a different currency. Replace the ledger to restore it without mixing currencies."
        case .unsupportedVersion(let version):
            return "This backup was made by a newer version of Inpenso (format \(version)). Update the app and try again."
        }
    }
}

enum BackupService {

    // MARK: - Export

    static func makeBackup() throws -> InpensoBackup {
        guard let ledger = StorageService.loadLedger() else { throw WalletError.storageFailure }
        return InpensoBackup(
            formatVersion: InpensoBackup.currentFormatVersion,
            exportedAt: Date(),
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
            currencyCode: ledger.currency,
            transactions: ledger.transactions,
            budgets: StorageService.loadBudgets(),
            categoryCatalog: StorageService.loadCategoryCatalogState(),
            recurringRules: RecurringService.loadRules(),
            categoryBudgets: CategoryBudgetService.load(),
            wallets: ledger.wallets,
            transfers: ledger.transfers,
            defaultWalletID: ledger.defaultWalletID
        )
    }

    /// Writes a backup to a temporary file for the share sheet.
    static func writeBackupFile() throws -> URL {
        let data = try encode(makeBackup())
        let stamp = Date().formatted(.iso8601.year().month().day())
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("Inpenso-backup-\(stamp).json")
        try data.write(to: url, options: .atomic)
        return url
    }

    static func encode(_ backup: InpensoBackup) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(backup)
    }

    // MARK: - Import

    /// Reads a versioned backup, or the legacy expenses-only export.
    static func readBackup(from data: Data, currentCurrencyCode: String) throws -> (backup: InpensoBackup, isLegacy: Bool) {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        struct Header: Decodable { let formatVersion: Int }
        if let header = try? decoder.decode(Header.self, from: data) {
            guard (1...InpensoBackup.currentFormatVersion).contains(header.formatVersion) else {
                throw BackupError.unsupportedVersion(header.formatVersion)
            }
            guard let backup = try? decoder.decode(InpensoBackup.self, from: data) else {
                throw BackupError.unreadableFile
            }
            if backup.formatVersion == 2 {
                var ledger = try makeLedger(from: backup)
                do { try ledger.prepareForWrite() } catch { throw BackupError.unreadableFile }
            }
            return (backup, false)
        }

        // Legacy export: a bare [Expense] array with default date encoding and no currency.
        if let expenses = try? JSONDecoder().decode([Expense].self, from: data) {
            let backup = InpensoBackup(
                formatVersion: 0,
                exportedAt: Date(),
                appVersion: nil,
                currencyCode: currentCurrencyCode,
                transactions: expenses,
                budgets: [:],
                categoryCatalog: nil,
                recurringRules: nil,
                categoryBudgets: nil
            )
            return (backup, true)
        }

        throw BackupError.unreadableFile
    }

    static func preview(_ backup: InpensoBackup, isLegacy: Bool, currentCurrencyCode: String) -> RestorePreview {
        let ledger = StorageService.loadLedger()
        let existingIDs = Set((ledger?.transactions ?? []).map(\.id))
        let incomingIDs = Set(backup.transactions.map(\.id))
        let duplicates = incomingIDs.intersection(existingIDs).count

        let existingBudgets = StorageService.loadBudgets()
        let newBudgets = backup.budgets.keys.filter { existingBudgets[$0] == nil }.count

        let existingCategoryIDs = Set((StorageService.loadCategoryCatalogState()?.customCategories ?? []).map(\.id))
        let newCategories = (backup.categoryCatalog?.customCategories ?? [])
            .filter { !existingCategoryIDs.contains($0.id) }.count

        let existingWalletIDs = Set((ledger?.wallets ?? []).map(\.id))
        let existingTransferIDs = Set((ledger?.transfers ?? []).map(\.id))
        return RestorePreview(
            backup: backup,
            isLegacyFormat: isLegacy,
            newTransactionCount: incomingIDs.count - duplicates,
            duplicateTransactionCount: duplicates,
            newBudgetCount: newBudgets,
            newCustomCategoryCount: newCategories,
            currentCurrencyCode: ledger?.currency ?? currentCurrencyCode,
            newWalletCount: Set((backup.wallets ?? []).map(\.id)).subtracting(existingWalletIDs).count,
            newTransferCount: Set((backup.transfers ?? []).map(\.id)).subtracting(existingTransferIDs).count
        )
    }

    /// Applies a backup to storage. Returns the committed ledger currency.
    @discardableResult
    static func restore(_ backup: InpensoBackup, mode: RestoreMode, importWalletID: UUID? = nil) throws -> String? {
        let currency = try StorageService.updateLedger { ledger in
            if mode == .merge, backup.formatVersion > 0, backup.currencyCode != ledger.currency {
                throw BackupError.currencyMismatch
            }
            if backup.formatVersion >= 2 {
                let incoming = try makeLedger(from: backup)
                if mode == .replace { ledger = incoming } else { merge(incoming, into: &ledger) }
            } else {
                let targetID = importWalletID ?? ledger.defaultWalletID
                guard var target = ledger.wallets.first(where: { $0.id == targetID && !$0.isArchived })
                else { throw WalletError.unknownWallet }
                let imported = uniqueByID(backup.transactions).map {
                    var expense = $0
                    expense.walletID = targetID
                    return expense
                }
                if mode == .replace {
                    target.openingBalance = 0
                    target.openingDate = nil
                    ledger.wallets = [target]
                    ledger.defaultWalletID = targetID
                    ledger.transactions = imported
                    ledger.transfers = []
                    if backup.formatVersion > 0 { ledger.currency = backup.currencyCode }
                } else {
                    let ids = Set(ledger.transactions.map(\.id))
                    ledger.transactions += imported.filter { !ids.contains($0.id) }
                }
            }
            return ledger.currency
        }

        switch mode {
        case .replace:
            StorageService.saveBudgets(backup.budgets)
            if let catalog = backup.categoryCatalog {
                StorageService.saveCategoryCatalogState(catalog)
                StorageService.saveCustomCategories(catalog.customCategories)
            }
            var rules = backup.recurringRules ?? []
            if backup.formatVersion < 2 {
                for index in rules.indices { rules[index].walletID = nil }
            }
            RecurringService.saveRules(rules)
            CategoryBudgetService.save(backup.categoryBudgets ?? [:])

        case .merge:
            var budgets = StorageService.loadBudgets()
            budgets.merge(backup.budgets) { current, _ in current }
            StorageService.saveBudgets(budgets)

            if var incomingRules = backup.recurringRules {
                if backup.formatVersion < 2 {
                    for index in incomingRules.indices { incomingRules[index].walletID = importWalletID }
                }
                let rules = RecurringService.loadRules()
                let knownIDs = Set(rules.map(\.id))
                RecurringService.saveRules(rules + incomingRules.filter { !knownIDs.contains($0.id) })
            }
            if let incomingLimits = backup.categoryBudgets {
                CategoryBudgetService.save(CategoryBudgetService.load().merging(incomingLimits) { current, _ in current })
            }

            if let incoming = backup.categoryCatalog {
                var catalog = StorageService.loadCategoryCatalogState()
                    ?? CategoryCatalogState(
                        orderedCategoryIDs: FinanceCategory.builtInCategories.map(\.id),
                        customCategories: StorageService.loadCustomCategories()
                    )
                let knownIDs = Set(catalog.customCategories.map(\.id))
                let added = incoming.customCategories.filter { !knownIDs.contains($0.id) }
                catalog.customCategories += added
                catalog.orderedCategoryIDs += added.map(\.id)
                StorageService.saveCategoryCatalogState(catalog)
                StorageService.saveCustomCategories(catalog.customCategories)
            }
        }

        NotificationCenter.default.post(name: .inpensoDataDidChange, object: nil)
        return currency
    }

    private static func makeLedger(from backup: InpensoBackup) throws -> WalletLedger {
        guard let wallets = backup.wallets, let transfers = backup.transfers,
              let defaultWalletID = backup.defaultWalletID
        else { throw BackupError.unreadableFile }
        return WalletLedger(
            wallets: wallets,
            defaultWalletID: defaultWalletID,
            transactions: uniqueByID(backup.transactions),
            transfers: transfers,
            currency: backup.currencyCode
        )
    }

    private static func merge(_ incoming: WalletLedger, into ledger: inout WalletLedger) {
        var walletIDs = Set(ledger.wallets.map(\.id))
        ledger.wallets += incoming.wallets.filter { walletIDs.insert($0.id).inserted }

        let incomingFeeIDs = Set(incoming.transfers.compactMap(\.feeExpenseID))
        var expenseIDs = Set(ledger.transactions.map(\.id))
        ledger.transactions += incoming.transactions.filter {
            !incomingFeeIDs.contains($0.id) && expenseIDs.insert($0.id).inserted
        }

        var transferIDs = Set(ledger.transfers.map(\.id))
        for var transfer in incoming.transfers where transferIDs.insert(transfer.id).inserted {
            if let feeID = transfer.feeExpenseID, !expenseIDs.insert(feeID).inserted {
                let replacementID = UUID()
                transfer.feeExpenseID = replacementID
                expenseIDs.insert(replacementID)
            }
            ledger.transfers.append(transfer)
        }
    }

    private static func uniqueByID(_ expenses: [Expense]) -> [Expense] {
        var seen = Set<UUID>()
        return expenses.filter { seen.insert($0.id).inserted }
    }
}
