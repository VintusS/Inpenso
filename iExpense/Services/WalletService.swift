import Foundation

enum WalletService {
    static func loadWallets() -> [Wallet] {
        (StorageService.loadLedger()?.wallets ?? []).sorted {
            if $0.sortOrder == $1.sortOrder { return $0.id.uuidString < $1.id.uuidString }
            return $0.sortOrder < $1.sortOrder
        }
    }

    static func defaultWalletID() -> UUID? {
        StorageService.loadLedger()?.defaultWalletID
    }

    static func setDefaultWallet(_ id: UUID) throws {
        try StorageService.updateLedger { ledger in
            guard ledger.wallets.contains(where: { $0.id == id && !$0.isArchived })
            else { throw WalletError.unknownWallet }
            ledger.defaultWalletID = id
        }
        notify()
    }

    static func saveWallet(_ wallet: Wallet) throws {
        guard !wallet.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              wallet.openingBalance.isFinite
        else { throw WalletError.storageFailure }
        try StorageService.updateLedger { ledger in
            if let index = ledger.wallets.firstIndex(where: { $0.id == wallet.id }) {
                guard wallet.isArchived == ledger.wallets[index].isArchived else { throw WalletError.storageFailure }
                ledger.wallets[index] = wallet
            } else {
                guard !wallet.isArchived else { throw WalletError.unknownWallet }
                ledger.wallets.append(wallet)
            }
        }
        notify()
    }

    static func archiveWallet(_ id: UUID, replacementDefault: UUID?) throws {
        try StorageService.updateLedger { ledger in
            guard let index = ledger.wallets.firstIndex(where: { $0.id == id })
            else { throw WalletError.unknownWallet }
            guard !ledger.wallets[index].isArchived else { return }
            let alternatives = ledger.wallets.filter { !$0.isArchived && $0.id != id }
            guard !alternatives.isEmpty else { throw WalletError.lastActiveWallet }

            if ledger.defaultWalletID == id {
                guard let replacementDefault, alternatives.contains(where: { $0.id == replacementDefault })
                else { throw WalletError.unknownWallet }
                ledger.defaultWalletID = replacementDefault
            }
            ledger.wallets[index].isArchived = true
        }
        notify()
    }

    static func loadTransfers() -> [Transfer] {
        StorageService.loadLedger()?.transfers ?? []
    }

    static func saveTransfer(_ transfer: Transfer) throws {
        guard transfer.fromWalletID != transfer.toWalletID else { throw WalletError.sameWallet }
        let fee = transfer.feeAmount ?? 0
        guard transfer.amount.isFinite, transfer.amount > 0, fee.isFinite, fee >= 0
        else { throw WalletError.invalidAmount }

        try StorageService.updateLedger { ledger in
            let index = ledger.transfers.firstIndex(where: { $0.id == transfer.id })
            let existing = index.map { ledger.transfers[$0] }
            let endpoints = [
                (transfer.fromWalletID, existing?.fromWalletID),
                (transfer.toWalletID, existing?.toWalletID)
            ]
            for (id, priorID) in endpoints {
                guard let wallet = ledger.wallets.first(where: { $0.id == id }), !wallet.isArchived || id == priorID
                else { throw WalletError.unknownWallet }
                guard wallet.openingDate.map({ $0 <= transfer.date }) ?? true
                else { throw WalletError.invalidAmount }
            }

            var updated = transfer
            updated.feeAmount = fee > 0 ? fee : nil
            updated.feeExpenseID = fee > 0 ? (existing?.feeExpenseID ?? UUID()) : nil
            if let feeID = existing?.feeExpenseID {
                ledger.transactions.removeAll { $0.id == feeID }
            }
            if let index { ledger.transfers[index] = updated } else { ledger.transfers.append(updated) }
        }
        notify()
    }

    static func deleteTransfer(_ id: UUID) throws {
        try StorageService.updateLedger { ledger in
            guard let index = ledger.transfers.firstIndex(where: { $0.id == id }) else { return }
            if let feeID = ledger.transfers.remove(at: index).feeExpenseID {
                ledger.transactions.removeAll { $0.id == feeID }
            }
        }
        notify()
    }

    static func balances(asOf: Date = Date()) -> [UUID: Double] {
        guard let ledger = StorageService.loadLedger() else { return [:] }
        let wallets = Dictionary(ledger.wallets.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        var result = wallets.mapValues {
            ($0.openingDate.map { $0 <= asOf } ?? true) ? $0.openingBalance : 0
        }

        func includes(_ id: UUID, _ date: Date) -> Bool {
            guard let wallet = wallets[id] else { return false }
            return date <= asOf && (wallet.openingDate.map { $0 <= date } ?? true)
        }

        for expense in ledger.transactions {
            guard let id = expense.walletID, includes(id, expense.date) else { continue }
            result[id, default: 0] += expense.type == .income ? expense.price : -expense.price
        }
        for transfer in ledger.transfers {
            if includes(transfer.fromWalletID, transfer.date) { result[transfer.fromWalletID, default: 0] -= transfer.amount }
            if includes(transfer.toWalletID, transfer.date) { result[transfer.toWalletID, default: 0] += transfer.amount }
        }
        return result
    }

    private static func notify() {
        NotificationCenter.default.post(name: .inpensoDataDidChange, object: nil)
    }
}
