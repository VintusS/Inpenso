//
//  TransferSheet.swift
//  iExpense
//

import SwiftUI

/// Create or edit a transfer between two wallets, with an optional fee.
struct TransferSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @EnvironmentObject private var settingsViewModel: SettingsViewModel
    @ObservedObject var walletsViewModel: WalletsViewModel
    let existing: Transfer?

    @State private var fromWalletID: UUID?
    @State private var toWalletID: UUID?
    @State private var amountText = ""
    @State private var feeText = ""
    @State private var date = Date()
    @State private var note = ""
    @State private var errorMessage: String?
    @State private var showingDeleteConfirmation = false
    @State private var didLoad = false
    private let prefillAmount: Double?
    private let customTitle: String?

    /// `toWalletID`, `amount` and `title` prefill a new transfer, e.g. Pay Bill on a credit wallet.
    init(walletsViewModel: WalletsViewModel, transfer: Transfer?, fromWalletID: UUID? = nil,
         toWalletID: UUID? = nil, amount: Double? = nil, title: String? = nil) {
        self.walletsViewModel = walletsViewModel
        self.existing = transfer
        self.prefillAmount = amount
        self.customTitle = title
        _fromWalletID = State(initialValue: transfer?.fromWalletID ?? fromWalletID)
        _toWalletID = State(initialValue: transfer?.toWalletID ?? toWalletID)
        _date = State(initialValue: transfer?.date ?? Date())
        _note = State(initialValue: transfer?.note ?? "")
    }

    private var currency: String { settingsViewModel.selectedCurrency }

    private var input: AmountInput {
        AmountInput(fractionDigits: currencyFractionDigits(for: currency), locale: locale)
    }

    private var amount: Double? { input.value(of: amountText) }

    private var paysCredit: Bool { walletsViewModel.wallet(for: toWalletID)?.kind.isCredit == true }
    private var fee: Double { input.value(of: feeText) ?? 0 }

    private var validationMessage: String? {
        guard let fromWalletID, let toWalletID else { return "Choose both wallets." }
        if fromWalletID == toWalletID { return WalletError.sameWallet.errorDescription }
        guard let amount, amount > 0 else { return WalletError.invalidAmount.errorDescription }
        return nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    WalletPicker(title: "From", selection: $fromWalletID, wallets: walletsViewModel.wallets, including: existing?.fromWalletID)
                    Button {
                        swap(&fromWalletID, &toWalletID)
                    } label: {
                        Label("Swap", systemImage: "arrow.up.arrow.down")
                            .font(.subheadline)
                    }
                    WalletPicker(title: "To", selection: $toWalletID, wallets: walletsViewModel.wallets, including: existing?.toWalletID)
                } footer: {
                    if let from = walletsViewModel.wallet(for: fromWalletID) {
                        Text("\(from.name) has \(walletsViewModel.balance(of: from).formatted(.currency(code: currency))).")
                    }
                }

                Section {
                    CurrencyFormField(
                        label: "Amount",
                        amount: $amountText,
                        currencySymbol: locale.localizedCurrencySymbol(forCurrencyCode: currency) ?? currency,
                        fractionDigits: input.fractionDigits
                    )
                    .listRowInsets(EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8))
                    HStack {
                        Text("Fee")
                        AmountTextField(placeholder: "None", raw: $feeText, input: input)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: .infinity)
                    }
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                    TextField("Note (optional)", text: $note)
                } footer: {
                    if paysCredit {
                        Text(fee > 0
                             ? "Paying the bill lowers what you owe and isn't spending. The fee or interest is, under Fees & Interest."
                             : "Paying the bill lowers what you owe. The purchases already counted as spending, so this doesn't.")
                    } else {
                        Text(fee > 0
                             ? "The fee is taken from the source wallet and counted as spending. The transfer itself isn't."
                             : "Transfers don't count as income or spending.")
                    }
                }

                if existing != nil {
                    Section {
                        Button("Delete Transfer", role: .destructive) {
                            showingDeleteConfirmation = true
                        }
                    }
                }
            }
            .navigationTitle(existing == nil ? (customTitle ?? "Transfer") : "Edit Transfer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(validationMessage != nil)
                }
            }
            .confirmationDialog("Delete this transfer?", isPresented: $showingDeleteConfirmation, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    guard let existing else { return }
                    run { try walletsViewModel.delete(existing) }
                }
            } message: {
                Text("Both wallet balances go back. A linked fee is deleted too.")
            }
            .alert("Transfer", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage ?? "")
            }
            .onAppear(perform: load)
        }
    }

    private func load() {
        guard !didLoad else { return }
        didLoad = true
        if let existing {
            amountText = input.bindingText(for: existing.amount)
            if let fee = existing.feeAmount, fee > 0 {
                feeText = input.bindingText(for: fee)
            }
        } else {
            let active = walletsViewModel.activeWallets
            if fromWalletID == nil {
                // Paying a card from another card isn't a bill payment, so default to a cash or bank wallet.
                let sources = paysCredit ? active.filter { !$0.kind.isCredit } : active
                let preferred = walletsViewModel.defaultWalletID.flatMap { id in sources.first { $0.id == id } }
                fromWalletID = preferred?.id ?? sources.first { $0.id != toWalletID }?.id
            }
            if toWalletID == nil { toWalletID = active.first { $0.id != fromWalletID }?.id }
            if let prefillAmount, prefillAmount > 0 {
                amountText = input.bindingText(for: prefillAmount)
            }
        }
    }

    private func save() {
        guard validationMessage == nil, let fromWalletID, let toWalletID, let amount else { return }
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        var transfer = existing ?? Transfer(fromWalletID: fromWalletID, toWalletID: toWalletID, amount: amount, date: date)
        transfer.fromWalletID = fromWalletID
        transfer.toWalletID = toWalletID
        transfer.amount = amount
        transfer.date = date
        transfer.note = trimmed.isEmpty ? nil : trimmed
        transfer.feeAmount = fee > 0 ? fee : nil
        run { try walletsViewModel.save(transfer) }
    }

    private func run(_ action: () throws -> Void) {
        do {
            try action()
            HapticFeedback.success()
            dismiss()
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Couldn't save the transfer."
        }
    }
}
