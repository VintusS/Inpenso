//
//  WalletsViewModel.swift
//  iExpense
//

import Combine
import Foundation

/// One line in a wallet's history: a transaction or one side of a transfer.
struct WalletActivity: Identifiable {
    enum Kind {
        case transaction(Expense)
        case transferOut(Transfer, to: Wallet?)
        case transferIn(Transfer, from: Wallet?)
    }

    let kind: Kind

    var id: String {
        switch kind {
        case .transaction(let expense):
            return "tx-\(expense.id)"
        case .transferOut(let transfer, _):
            return "out-\(transfer.id)"
        case .transferIn(let transfer, _):
            return "in-\(transfer.id)"
        }
    }

    var date: Date {
        switch kind {
        case .transaction(let expense):
            return expense.date
        case .transferOut(let transfer, _), .transferIn(let transfer, _):
            return transfer.date
        }
    }

    /// Signed effect on this wallet's balance.
    var signedAmount: Double {
        switch kind {
        case .transaction(let expense):
            return expense.signedAmount
        case .transferOut(let transfer, _):
            return -transfer.amount
        case .transferIn(let transfer, _):
            return transfer.amount
        }
    }
}

@MainActor
final class WalletsViewModel: ObservableObject {
    @Published private(set) var wallets: [Wallet] = []
    @Published private(set) var balances: [UUID: Double] = [:]
    @Published private(set) var transfers: [Transfer] = []
    @Published private(set) var defaultWalletID: UUID?
    @Published private(set) var instalmentPlans: [InstalmentPlan] = []
    private var transactions: [Expense] = []

    init() {
        refresh()
    }

    var activeWallets: [Wallet] { wallets.filter { !$0.isArchived } }
    var archivedWallets: [Wallet] { wallets.filter(\.isArchived) }

    /// Sum over all wallets, archived included, so money in an archived wallet is not lost from view.
    var totalBalance: Double { wallets.reduce(0) { $0 + (balances[$1.id] ?? 0) } }

    func wallet(for id: UUID?) -> Wallet? {
        guard let id else { return nil }
        return wallets.first { $0.id == id }
    }

    func balance(of wallet: Wallet) -> Double { balances[wallet.id] ?? wallet.openingBalance }

    var assetsTotal: Double {
        wallets.filter { !$0.kind.isCredit }.reduce(0) { $0 + max(0, balance(of: $1)) }
    }

    var owedTotal: Double { wallets.reduce(0) { $0 + owed(for: $1) } }
    var netTotal: Double { assetsTotal - owedTotal }

    func owed(for wallet: Wallet) -> Double {
        guard wallet.kind.isCredit else { return 0 }
        return unsettled(-balance(of: wallet))
    }

    func available(for wallet: Wallet) -> Double? {
        guard wallet.kind.isCredit else { return nil }
        return wallet.creditLimit.map { $0 - owed(for: wallet) }
    }

    func isOverLimit(_ wallet: Wallet) -> Bool {
        available(for: wallet).map { $0 < 0 } ?? false
    }

    func setAmountOwed(_ owed: Double, for wallet: Wallet) throws {
        guard wallet.kind.isCredit else { throw WalletError.unknownWallet }
        guard owed.isFinite, owed >= 0 else { throw WalletError.invalidAmount }
        try setCurrentBalance(of: wallet, to: -owed)
    }

    func nextDueDate(for wallet: Wallet, from: Date = .now) -> Date? {
        guard wallet.kind.isCredit, let day = wallet.dueDay else { return nil }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: from)
        guard let due = creditDate(day: day, inMonthOf: today) else { return nil }
        if due >= today { return due }
        guard let nextMonth = calendar.date(byAdding: .month, value: 1, to: due) else { return nil }
        return creditDate(day: day, inMonthOf: nextMonth)
    }

    func progress(of plan: InstalmentPlan) -> InstalmentProgress {
        progress(of: plan, asOf: .now)
    }

    func progress(of plan: InstalmentPlan, asOf date: Date) -> InstalmentProgress {
        guard let wallet = wallet(for: plan.creditWalletID) else { return PlanPayment().progress(for: plan) }
        return (allocatePayments(for: wallet, asOf: date).plans[plan.id] ?? PlanPayment()).progress(for: plan)
    }

    func dueThisStatement(for wallet: Wallet) -> Double {
        let date = Date.now
        return statementAmounts(for: wallet, asOf: date, payments: allocatePayments(for: wallet, asOf: date)).total
    }

    private func statementAmounts(
        for wallet: Wallet, asOf date: Date, payments: CardPayments
    ) -> (total: Double, regular: Double) {
        guard wallet.kind.isCredit else { return (0, 0) }
        let calendar = Calendar.current
        let due = nextDueDate(for: wallet, from: date)
        let cutoff = statementCutoff(for: wallet, due: due, asOf: date)
        let regularBilled = payments.regularBills.lazy.filter { calendar.startOfDay(for: $0.date) <= cutoff }
            .reduce(0) { $0 + $1.price }
        let regular = unsettled(regularBilled - payments.paidRegular)
        let instalments = instalmentPlans.lazy.filter { $0.creditWalletID == wallet.id }.reduce(0.0) { total, plan in
            let payment = payments.plans[plan.id] ?? PlanPayment()
            let status = payment.progress(for: plan)
            let count = scheduledCount(for: plan, through: due ?? cutoff)
            guard count > status.paidCount else { return total }
            let billed = scheduledPrincipal(for: plan, count: count)
                - scheduledPrincipal(for: plan, count: status.paidCount) - payment.partial
            return total + unsettled(billed)
        }
        return (regular + instalments, regular)
    }

    private func statementCutoff(for wallet: Wallet, due: Date?, asOf date: Date) -> Date {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: date)
        guard let day = wallet.statementDay, let cutoff = creditDate(day: day, inMonthOf: due ?? today)
        else { return today }
        if cutoff <= today && (due.map { cutoff < $0 || day == wallet.dueDay } ?? true) { return cutoff }
        guard let prior = calendar.date(byAdding: .month, value: -1, to: cutoff),
              let priorCutoff = creditDate(day: day, inMonthOf: prior)
        else { return today }
        // The due day can fall before the next statement closes.
        return min(priorCutoff, today)
    }

    private func scheduledCount(for plan: InstalmentPlan, through date: Date) -> Int {
        let calendar = Calendar.current
        let end = calendar.startOfDay(for: date)
        let start = calendar.startOfDay(for: plan.firstDueDate)
        guard start <= end,
              let fromMonth = calendar.dateInterval(of: .month, for: start)?.start,
              let toMonth = calendar.dateInterval(of: .month, for: end)?.start,
              let index = calendar.dateComponents([.month], from: fromMonth, to: toMonth).month
        else { return 0 }
        if index >= plan.months { return plan.months }
        let due = plan.dueDate(at: index).map { calendar.startOfDay(for: $0) }
        return index + (due.map { $0 <= end } == true ? 1 : 0)
    }

    func upcomingDues(within days: Int = 7, from: Date = .now) -> [DueItem] {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: from)
        guard days >= 0, let end = calendar.date(byAdding: .day, value: days, to: start) else { return [] }
        let paymentsByWallet = Dictionary(uniqueKeysWithValues: activeWallets.filter(\.kind.isCredit).map {
            ($0.id, allocatePayments(for: $0, asOf: from))
        })
        let instalments = instalmentPlans.compactMap { plan -> DueItem? in
            guard let payments = paymentsByWallet[plan.creditWalletID] else { return nil }
            let payment = payments.plans[plan.id] ?? PlanPayment()
            let status = payment.progress(for: plan)
            guard let date = status.nextDueDate, calendar.startOfDay(for: date) <= end else { return nil }
            let billed = scheduledPrincipal(for: plan, count: status.paidCount + 1)
                - scheduledPrincipal(for: plan, count: status.paidCount)
            let amount = unsettled(billed - payment.partial) + plan.monthlyFee
            return DueItem(
                id: "instalment-\(plan.id)", kind: .instalment(plan.id), walletID: plan.creditWalletID,
                title: plan.title, amount: amount, dueDate: date
            )
        }
        let cards = activeWallets.compactMap { wallet -> DueItem? in
            guard let date = nextDueDate(for: wallet, from: from), date <= end,
                  let payments = paymentsByWallet[wallet.id] else { return nil }
            let amount = statementAmounts(for: wallet, asOf: from, payments: payments).regular
            guard amount > 0 else { return nil }
            return DueItem(
                id: "card-\(wallet.id)", kind: .cardDue(wallet.id), walletID: wallet.id,
                title: wallet.name, amount: amount, dueDate: date
            )
        }
        return (instalments + cards).sorted { ($0.dueDate, $0.id) < ($1.dueDate, $1.id) }
    }

    private func unsettled(_ amount: Double) -> Double { amount >= 1 ? amount : 0 }

    func refresh() {
        let ledger = StorageService.loadLedger()
        wallets = (ledger?.wallets ?? []).sorted { ($0.sortOrder, $0.id.uuidString) < ($1.sortOrder, $1.id.uuidString) }
        balances = ledger.map { WalletService.balances(in: $0, asOf: .now) } ?? [:]
        transfers = ledger?.transfers ?? []
        defaultWalletID = ledger?.defaultWalletID
        instalmentPlans = ledger?.instalmentPlans ?? []
        transactions = ledger?.transactions ?? []
        #if DEBUG
        if StorageService.isUnitTestHost { return }
        #endif
        // Look 40 days ahead so the next due date of every card and plan is covered.
        let names = Dictionary(uniqueKeysWithValues: wallets.map { ($0.id, $0.name) })
        CreditDueReminder.reschedule(dues: upcomingDues(within: 40)) { names[$0] }
    }

    /// Newest first.
    func activity(for wallet: Wallet, expenses: [Expense]) -> [WalletActivity] {
        var items = expenses
            .filter { $0.walletID == wallet.id }
            .map { WalletActivity(kind: .transaction($0)) }
        for transfer in transfers {
            if transfer.fromWalletID == wallet.id {
                items.append(WalletActivity(kind: .transferOut(transfer, to: self.wallet(for: transfer.toWalletID))))
            }
            if transfer.toWalletID == wallet.id {
                items.append(WalletActivity(kind: .transferIn(transfer, from: self.wallet(for: transfer.fromWalletID))))
            }
        }
        return items.sorted { $0.date > $1.date }
    }

    func isFee(_ expense: Expense) -> Bool {
        transfers.contains { $0.feeExpenseID == expense.id }
    }

    // MARK: Actions (errors surface to the caller for an alert)

    func save(_ wallet: Wallet) throws {
        try WalletService.saveWallet(wallet)
        refresh()
    }

    func setCurrentBalance(of wallet: Wallet, to amount: Double) throws {
        try WalletService.setCurrentBalance(wallet.id, to: amount)
        refresh()
    }

    func payInstalment(_ plan: InstalmentPlan, amount: Double, from walletID: UUID, date: Date) throws {
        try WalletService.payInstalment(plan, amount: amount, from: walletID, date: date)
        refresh()
    }

    func archive(_ wallet: Wallet) throws {
        let replacement = activeWallets.first { $0.id != wallet.id }?.id
        try WalletService.archiveWallet(wallet.id, replacementDefault: replacement)
        refresh()
    }

    func unarchive(_ wallet: Wallet) throws {
        try WalletService.unarchiveWallet(wallet.id)
        refresh()
    }

    func makeDefault(_ wallet: Wallet) throws {
        try WalletService.setDefaultWallet(wallet.id)
        refresh()
    }

    func save(_ transfer: Transfer) throws {
        try WalletService.saveTransfer(transfer)
        refresh()
    }

    func delete(_ transfer: Transfer) throws {
        try WalletService.deleteTransfer(transfer.id)
        refresh()
    }
}

private extension WalletsViewModel {
    struct PlanPayment {
        var paidCount = 0
        var paidPrincipal = 0.0
        var partial = 0.0

        func progress(for plan: InstalmentPlan) -> InstalmentProgress {
            let remaining = plan.principal - paidPrincipal
            let finished = paidCount == plan.months || remaining < 1
            return InstalmentProgress(
                paidCount: finished ? plan.months : paidCount,
                remainingPrincipal: finished ? 0 : remaining,
                nextDueDate: finished ? nil : plan.dueDate(at: paidCount), isFinished: finished
            )
        }
    }

    struct CardPayments {
        var plans: [UUID: PlanPayment] = [:]
        var regularBills: [Expense] = []
        var paidRegular = 0.0
    }

    func scheduledPrincipal(for plan: InstalmentPlan, count: Int) -> Double {
        count == plan.months ? plan.principal : min(plan.principal, Double(count) * plan.monthlyAmount)
    }

    func allocatePayments(for wallet: Wallet, asOf date: Date) -> CardPayments {
        let plans = instalmentPlans.filter { $0.creditWalletID == wallet.id }
        let purchaseIDs = Set(plans.compactMap(\.purchaseExpenseID))
        let activity = transactions.filter { transaction in
            transaction.walletID == wallet.id && transaction.date <= date
                && (wallet.openingDate.map { $0 <= transaction.date } ?? true)
        }
        var result = CardPayments()
        result.regularBills = activity.filter { $0.type == .expense && $0.price > 0 && !purchaseIDs.contains($0.id) }
            .sorted { ($0.date, $0.id.uuidString) < ($1.date, $1.id.uuidString) }

        let incomingTransfers = transfers.filter { $0.toWalletID == wallet.id && $0.date <= date }
            .map { (date: $0.date, id: $0.id, amount: $0.amount) }
        let refunds = activity.filter { $0.type == .refund && $0.price > 0 }
            .map { (date: $0.date, id: $0.id, amount: $0.price) }
        var payments = (incomingTransfers + refunds)
            .sorted { ($0.date, $0.id.uuidString) < ($1.date, $1.id.uuidString) }.makeIterator()

        var ordinaryIndex = 0
        var paidTowardOrdinaryBill = 0.0
        var funds = 0.0
        while true {
            if funds == 0 {
                guard let payment = payments.next() else { break }
                funds = payment.amount
            }
            let nextPlan = plans.compactMap { plan -> (InstalmentPlan, Date)? in
                let payment = result.plans[plan.id] ?? PlanPayment()
                return payment.progress(for: plan).nextDueDate.map { (plan, $0) }
            }.min { ($0.1, $0.0.id.uuidString) < ($1.1, $1.0.id.uuidString) }
            let ordinary = result.regularBills.indices.contains(ordinaryIndex) ? result.regularBills[ordinaryIndex] : nil
            if let bill = ordinary, nextPlan.map({ bill.date < $0.1 }) ?? true {
                let balance = bill.price - paidTowardOrdinaryBill
                let paid = min(funds, balance)
                funds -= paid
                result.paidRegular += paid
                if paid == balance {
                    ordinaryIndex += 1
                    paidTowardOrdinaryBill = 0
                } else {
                    paidTowardOrdinaryBill += paid
                }
            } else if let (plan, _) = nextPlan {
                var payment = result.plans[plan.id] ?? PlanPayment()
                let index = payment.paidCount
                let billed = scheduledPrincipal(for: plan, count: index + 1) - scheduledPrincipal(for: plan, count: index)
                let balance = billed - payment.partial
                let paid = min(funds, balance)
                funds -= paid
                payment.paidPrincipal += paid
                if balance - paid < 1 {
                    payment.paidCount += 1
                    payment.partial = 0
                } else {
                    payment.partial += paid
                }
                result.plans[plan.id] = payment
            } else {
                break
            }
        }
        return result
    }
}
