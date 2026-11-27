//
//  DueSoonCard.swift
//  iExpense
//

import SwiftUI

/// Home card: card bills and instalments due within the next week, each with a Pay action.
struct DueSoonCard: View {
    @EnvironmentObject private var walletsViewModel: WalletsViewModel
    @EnvironmentObject private var settingsViewModel: SettingsViewModel
    @State private var payingBill: Wallet?
    @State private var payingPlan: InstalmentPlan?
    @State private var errorMessage: String?

    let dues: [DueItem]

    private var currency: String { settingsViewModel.selectedCurrency }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Due Soon")
                .font(.headline)

            ForEach(dues.prefix(5)) { item in
                row(for: item)
                if item.id != dues.prefix(5).last?.id {
                    Divider().padding(.leading, 40)
                }
            }
            if dues.count > 5 {
                Text("+\(dues.count - 5) more")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.secondarySystemBackground))
                .shadow(color: Color(.label).opacity(0.05), radius: 10, x: 0, y: 5)
        )
        .sheet(item: $payingBill) { wallet in
            TransferSheet(
                walletsViewModel: walletsViewModel,
                transfer: nil,
                toWalletID: wallet.id,
                amount: billAmount(for: wallet),
                title: "Pay Bill"
            )
        }
        .confirmationDialog(
            payingPlan.map { "Pay \($0.title)" } ?? "",
            isPresented: Binding(get: { payingPlan != nil }, set: { if !$0 { payingPlan = nil } }),
            titleVisibility: .visible,
            presenting: payingPlan
        ) { plan in
            ForEach(payFromChoices(for: plan)) { source in
                Button("From \(source.name)") { pay(plan, from: source) }
            }
        } message: { plan in
            Text("\(plan.monthlyAmount.formatted(.currency(code: currency))) is recorded as a transfer to the card.")
        }
        .alert("Due Soon", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func row(for item: DueItem) -> some View {
        let wallet = walletsViewModel.wallet(for: item.walletID)
        let overdue = item.dueDate < Calendar.current.startOfDay(for: Date())
        return HStack(spacing: 12) {
            if let wallet {
                WalletIcon(wallet: wallet, size: 28)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                HStack(spacing: 4) {
                    Text(overdue ? "Overdue" : dueText(item.dueDate))
                        .foregroundColor(overdue ? .red : .secondary)
                    Text("·")
                    Text(item.amount, format: .currency(code: currency))
                        .monospacedDigit()
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button("Pay") { startPayment(item, wallet: wallet) }
                .font(.caption.weight(.semibold))
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .frame(minHeight: 44)
                .accessibilityLabel("Pay \(item.title)")
        }
        .accessibilityElement(children: .contain)
    }

    private func dueText(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "Due today" }
        if calendar.isDateInTomorrow(date) { return "Due tomorrow" }
        return "Due \(date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)))"
    }

    private func startPayment(_ item: DueItem, wallet: Wallet?) {
        switch item.kind {
        case .instalment(let planID):
            payingPlan = walletsViewModel.instalmentPlans.first { $0.id == planID }
        case .cardDue:
            payingBill = wallet
        }
    }

    private func billAmount(for wallet: Wallet) -> Double {
        let due = walletsViewModel.dueThisStatement(for: wallet)
        return due > 0 ? due : walletsViewModel.owed(for: wallet)
    }

    private func payFromChoices(for plan: InstalmentPlan) -> [Wallet] {
        let sources = walletsViewModel.activeWallets.filter { !$0.kind.isCredit }
        guard let preferred = sources.first(where: { $0.id == plan.payFromWalletID }) else { return sources }
        return [preferred] + sources.filter { $0.id != preferred.id }
    }

    private func pay(_ plan: InstalmentPlan, from source: Wallet) {
        do {
            try walletsViewModel.payInstalment(plan, amount: plan.monthlyAmount, from: source.id, date: Date())
            HapticFeedback.success()
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Couldn't record the payment."
        }
    }
}
