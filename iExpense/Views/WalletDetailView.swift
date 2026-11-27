//
//  WalletDetailView.swift
//  iExpense
//

import SwiftUI

struct WalletDetailView: View {
    let walletID: UUID
    @ObservedObject var walletsViewModel: WalletsViewModel
    @ObservedObject var expenseViewModel: ExpenseViewModel
    @EnvironmentObject private var settingsViewModel: SettingsViewModel
    @EnvironmentObject private var categoryStore: CategoryStore
    @State private var editingWallet: Wallet?
    @State private var editingTransfer: Transfer?
    @State private var showingTransfer = false
    @State private var showingSetBalance = false
    @State private var showingPayBill = false
    @State private var payingPlan: InstalmentPlan?
    @State private var errorMessage: String?

    private var currency: String { settingsViewModel.selectedCurrency }

    var body: some View {
        Group {
            if let wallet = walletsViewModel.wallet(for: walletID) {
                content(wallet)
            } else {
                Text("This wallet no longer exists.")
                    .foregroundColor(.secondary)
            }
        }
        .alert("Wallet", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func content(_ wallet: Wallet) -> some View {
        let activity = walletsViewModel.activity(for: wallet, expenses: expenseViewModel.expenses)
        let balance = walletsViewModel.balance(of: wallet)
        return List {
            if wallet.kind.isCredit {
                creditSummary(wallet)
                instalmentsSection(wallet)
            } else {
                balanceSection(wallet, balance: balance)
            }

            historySection(wallet, activity: activity)

            Section {
                if wallet.id != walletsViewModel.defaultWalletID && !wallet.isArchived && !wallet.kind.isCredit {
                    Button("Make Default Wallet") {
                        run { try walletsViewModel.makeDefault(wallet) }
                    }
                }
                if wallet.isArchived {
                    Button("Unarchive") {
                        run { try walletsViewModel.unarchive(wallet) }
                    }
                } else {
                    Button("Archive Wallet", role: .destructive) {
                        run { try walletsViewModel.archive(wallet) }
                    }
                }
            } footer: {
                Text(wallet.isArchived
                     ? "Archived wallets keep their history and balance but can't be picked for new entries."
                     : "Archiving hides the wallet from pickers. Its history and balance stay.")
            }
        }
        .navigationTitle(wallet.name)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Edit") { editingWallet = wallet }
            }
        }
        .sheet(item: $editingWallet) { wallet in
            WalletEditor(wallet: wallet, isNew: false, onSave: { try walletsViewModel.save($0) })
        }
        .sheet(isPresented: $showingSetBalance) {
            SetBalanceSheet(wallet: wallet, currentBalance: balance) {
                try walletsViewModel.setCurrentBalance(of: wallet, to: $0)
            }
        }
        .sheet(isPresented: $showingTransfer) {
            TransferSheet(walletsViewModel: walletsViewModel, transfer: nil, fromWalletID: wallet.id)
        }
        .sheet(isPresented: $showingPayBill) {
            TransferSheet(
                walletsViewModel: walletsViewModel,
                transfer: nil,
                toWalletID: wallet.id,
                amount: billAmount(for: wallet),
                title: "Pay Bill"
            )
        }
        .sheet(item: $editingTransfer) { transfer in
            TransferSheet(walletsViewModel: walletsViewModel, transfer: transfer)
        }
        .confirmationDialog(
            payingPlan.map { "Pay \($0.title)" } ?? "",
            isPresented: Binding(get: { payingPlan != nil }, set: { if !$0 { payingPlan = nil } }),
            titleVisibility: .visible,
            presenting: payingPlan
        ) { plan in
            ForEach(payFromChoices(for: plan)) { source in
                Button("From \(source.name)") {
                    run {
                        try walletsViewModel.payInstalment(plan, amount: plan.monthlyAmount, from: source.id, date: Date())
                        HapticFeedback.success()
                    }
                }
            }
        } message: { plan in
            Text(plan.monthlyFee > 0
                 ? "\(plan.monthlyAmount.formatted(.currency(code: currency))) plus a \(plan.monthlyFee.formatted(.currency(code: currency))) fee, recorded as a transfer to \(wallet.name)."
                 : "\(plan.monthlyAmount.formatted(.currency(code: currency))), recorded as a transfer to \(wallet.name).")
        }
    }

    private func balanceSection(_ wallet: Wallet, balance: Double) -> some View {
        Section {
            HStack(spacing: 14) {
                WalletIcon(wallet: wallet, size: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Balance")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(balance, format: .currency(code: currency))
                        .font(.title2.bold())
                        .foregroundColor(balance < 0 ? .red : .primary)
                }
            }
            .padding(.vertical, 4)
            if balance < 0 {
                Label("This wallet is below zero. Check for a missing income or transfer.", systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundColor(.orange)
            }
            if !wallet.isArchived {
                Button {
                    showingTransfer = true
                } label: {
                    Label("Transfer", systemImage: "arrow.left.arrow.right")
                }
                .disabled(walletsViewModel.activeWallets.count < 2)
                Button {
                    showingSetBalance = true
                } label: {
                    Label("Set Current Balance", systemImage: "equal.circle")
                }
            }
        }
    }

    private func historySection(_ wallet: Wallet, activity: [WalletActivity]) -> some View {
        Section("History") {
            if activity.isEmpty && wallet.openingBalance == 0 {
                Text("No activity yet")
                    .foregroundColor(.secondary)
            }
            ForEach(activity) { item in
                activityRow(item)
            }
            if wallet.openingBalance != 0 {
                HStack {
                    Label(wallet.kind.isCredit ? "Owed at start" : "Opening balance", systemImage: "flag")
                        .font(.subheadline)
                    Spacer()
                    Text(wallet.kind.isCredit ? -wallet.openingBalance : wallet.openingBalance,
                         format: .currency(code: currency))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private func activityRow(_ item: WalletActivity) -> some View {
        switch item.kind {
        case .transaction(let expense):
            let category = categoryStore.category(for: expense)
            row(
                for: item,
                icon: Image(systemName: category.iconName), color: category.color,
                title: expense.title,
                subtitle: walletsViewModel.isFee(expense) ? "Transfer fee" : category.displayName
            )
        case .transferOut(let transfer, let to):
            Button { editingTransfer = transfer } label: {
                row(for: item, icon: Image(systemName: "arrow.up.right"), color: .gray,
                    title: "To \(to?.name ?? "deleted wallet")", subtitle: transfer.note ?? "Transfer")
            }
        case .transferIn(let transfer, let from):
            Button { editingTransfer = transfer } label: {
                row(for: item, icon: Image(systemName: "arrow.down.left"), color: .gray,
                    title: "From \(from?.name ?? "deleted wallet")", subtitle: transfer.note ?? "Transfer")
            }
        }
    }

    private func row(for item: WalletActivity, icon: Image, color: Color, title: String, subtitle: String) -> some View {
        let date = item.date
        let amount = item.signedAmount
        return HStack(spacing: 12) {
            icon
                .font(.footnote)
                .foregroundStyle(color.badgeForeground)
                .frame(width: 28, height: 28)
                .background(color)
                .cornerRadius(6)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                HStack(spacing: 4) {
                    Text(date, style: .date)
                    Text("·")
                    Text(subtitle)
                }
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)
            }
            Spacer()
            Text((amount > 0 ? "+" : "") + amount.formatted(.currency(code: currency)))
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(amount > 0 ? .green : .primary)
        }
    }

    private func run(_ action: () throws -> Void) {
        do { try action() } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Something went wrong."
        }
    }
}

// MARK: - Credit wallets

extension WalletDetailView {
    /// Statement amount when there is one, otherwise everything owed.
    private func billAmount(for wallet: Wallet) -> Double {
        let due = walletsViewModel.dueThisStatement(for: wallet)
        return due > 0 ? due : walletsViewModel.owed(for: wallet)
    }

    /// The plan's own pay-from wallet first, then the other active non-credit wallets.
    private func payFromChoices(for plan: InstalmentPlan) -> [Wallet] {
        let sources = walletsViewModel.activeWallets.filter { !$0.kind.isCredit }
        guard let preferred = sources.first(where: { $0.id == plan.payFromWalletID }) else { return sources }
        return [preferred] + sources.filter { $0.id != preferred.id }
    }

    @ViewBuilder
    private func creditSummary(_ wallet: Wallet) -> some View {
        let owed = walletsViewModel.owed(for: wallet)
        let available = walletsViewModel.available(for: wallet)
        let overLimit = walletsViewModel.isOverLimit(wallet)
        let due = walletsViewModel.dueThisStatement(for: wallet)
        Section {
            HStack(spacing: 14) {
                WalletIcon(wallet: wallet, size: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Owed")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(owed, format: .currency(code: currency))
                        .font(.title2.bold())
                        .foregroundColor(overLimit ? .red : .primary)
                        .monospacedDigit()
                }
                .accessibilityElement(children: .combine)
            }
            .padding(.vertical, 4)

            if let available {
                LabeledContent("Available") {
                    Text(available, format: .currency(code: currency)).monospacedDigit()
                }
            }
            if let limit = wallet.creditLimit {
                LabeledContent("Limit") {
                    Text(limit, format: .currency(code: currency)).monospacedDigit()
                }
            }
            if due > 0 {
                LabeledContent("This statement") {
                    Text(due, format: .currency(code: currency)).monospacedDigit()
                }
            }
            if let nextDue = walletsViewModel.nextDueDate(for: wallet) {
                LabeledContent("Next due") {
                    Text(nextDue, format: .dateTime.day().month(.abbreviated))
                }
            }
            if overLimit, let limit = wallet.creditLimit {
                Label("Over the limit by \((owed - limit).formatted(.currency(code: currency))).",
                      systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundColor(.orange)
            }

            if !wallet.isArchived {
                Button {
                    showingPayBill = true
                } label: {
                    Text(owed > 0 ? "Pay Bill" : "Nothing Owed")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
                .disabled(owed <= 0 || walletsViewModel.activeWallets.filter { !$0.kind.isCredit }.isEmpty)
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))

                Button {
                    showingSetBalance = true
                } label: {
                    Label("Set Amount Owed", systemImage: "equal.circle")
                }
            }
        } footer: {
            if wallet.statementDay == nil && wallet.dueDay == nil {
                Text("Add a statement day and due day in Edit to see what's due and when.")
            }
        }
    }

    @ViewBuilder
    private func instalmentsSection(_ wallet: Wallet) -> some View {
        let plans = walletsViewModel.instalmentPlans.filter { $0.creditWalletID == wallet.id }
        if !plans.isEmpty {
            Section("Instalments") {
                ForEach(plans) { plan in
                    instalmentRow(plan, archived: wallet.isArchived)
                }
            }
        }
    }

    private func instalmentRow(_ plan: InstalmentPlan, archived: Bool) -> some View {
        let progress = walletsViewModel.progress(of: plan)
        return HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(plan.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text("\(progress.paidCount) of \(plan.months) paid · \(progress.remainingPrincipal.formatted(.currency(code: currency))) left")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .monospacedDigit()
                if let next = progress.nextDueDate, !progress.isFinished {
                    Text("Next \(next.formatted(.dateTime.day().month(.abbreviated))) · \(plan.monthlyAmount.formatted(.currency(code: currency)))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if progress.isFinished {
                Label("Paid off", systemImage: "checkmark.circle.fill")
                    .labelStyle(.iconOnly)
                    .foregroundColor(.green)
                    .accessibilityLabel("Paid off")
            } else if !archived {
                Button("Pay") { payingPlan = plan }
                    .font(.subheadline.weight(.semibold))
                    .buttonStyle(.bordered)
                    .frame(minHeight: 44)
            }
        }
        .accessibilityElement(children: .contain)
    }
}
