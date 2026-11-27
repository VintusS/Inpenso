//
//  SetBalanceSheet.swift
//  iExpense
//

import SwiftUI

/// Asks for the balance the bank or e-wallet app shows right now and back-solves the opening balance.
struct SetBalanceSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @EnvironmentObject private var settingsViewModel: SettingsViewModel
    @State private var amountText = ""
    @State private var errorMessage: String?
    let wallet: Wallet
    let currentBalance: Double
    let onSave: (Double) throws -> Void

    private var currency: String { settingsViewModel.selectedCurrency }

    /// Credit wallets store debt as a negative balance; this sheet asks for the amount owed as a positive number.
    private var isCredit: Bool { wallet.kind.isCredit }

    /// The balance to store for what the user typed.
    private func targetBalance(_ entered: Double) -> Double { isCredit ? -abs(entered) : entered }

    private var input: AmountInput {
        AmountInput(fractionDigits: currencyFractionDigits(for: currency), locale: locale)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Text(isCredit ? "Owed now" : "Balance now")
                        AmountTextField(placeholder: input.placeholder, raw: $amountText, input: input)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: .infinity)
                    }
                } footer: {
                    Text(isCredit
                         ? "Enter what the \(wallet.name) app or statement says you owe today. The amount owed at start is adjusted to match; "
                            + "your recorded entries stay as they are."
                         : "Enter what \(wallet.name) actually holds today. The starting balance is adjusted to match; "
                            + "your recorded entries stay as they are.")
                }
                Section {
                    LabeledContent(isCredit ? "Inpenso shows owed" : "Inpenso shows",
                                   value: isCredit ? max(-currentBalance, 0) : currentBalance,
                                   format: .currency(code: currency))
                    if let entered = input.value(of: amountText) {
                        let opening = wallet.openingBalance + targetBalance(entered) - currentBalance
                        LabeledContent(isCredit ? "Owed at start becomes" : "Starting balance becomes",
                                       value: isCredit ? -opening : opening,
                                       format: .currency(code: currency))
                    }
                }
            }
            .navigationTitle(isCredit ? "Set Amount Owed" : "Set Current Balance")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(input.value(of: amountText) == nil)
                }
            }
            .alert("Wallet", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private func save() {
        guard let entered = input.value(of: amountText) else { return }
        do {
            try onSave(targetBalance(entered))
            dismiss()
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Couldn't update the balance."
        }
    }
}
