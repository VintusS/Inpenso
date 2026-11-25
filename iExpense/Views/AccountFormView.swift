//
//  AccountFormView.swift
//  iExpense
//
//  Create or edit a bank account / card.
//

import SwiftUI

private enum CreditBalanceInputMode: String, CaseIterable, Identifiable {
    case consumed
    case available

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .consumed: return String(localized: "Consumed")
        case .available: return String(localized: "Available Balance")
        }
    }
}

struct AccountFormView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var settingsViewModel: SettingsViewModel

    let account: Account?
    var onSave: (() -> Void)?

    @State private var name: String = ""
    @State private var type: AccountType = .debit
    @State private var creditLimit: String = ""
    @State private var creditInputMode: CreditBalanceInputMode = .available
    @State private var creditConsumed: String = ""
    @State private var creditAvailable: String = ""
    @State private var initialBalance: String = ""
    @State private var cutDay: Int = 1
    @State private var graceDays: Int = 20

    @State private var showingValidationAlert = false
    @State private var validationMessage = ""

    private var currencyCode: String {
        settingsViewModel.selectedCurrency
    }

    private var currencySymbol: String {
        let locale = Locale.current
        return locale.localizedCurrencySymbol(forCurrencyCode: currencyCode) ?? currencyCode
    }

    private var isCredit: Bool { type == .credit }

    private var limitValue: Double {
        Double(creditLimit) ?? 0
    }

    private var calculatedConsumed: Double {
        switch creditInputMode {
        case .consumed:
            return max(0, Double(creditConsumed) ?? 0)
        case .available:
            guard !creditAvailable.isEmpty else { return 0 }
            let avail = Double(creditAvailable) ?? 0
            return max(0, limitValue - avail)
        }
    }

    private var calculatedAvailable: Double {
        limitValue - calculatedConsumed
    }

    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextFormField(label: "Name", text: $name,
                                  placeholder: "Account name")
                    Picker(String(localized: "Type"), selection: $type) {
                        ForEach(AccountType.allCases) { t in
                            Text(t.displayName).tag(t)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                if isCredit {
                    Section(String(localized: "Credit Limit")) {
                        CurrencyFormField(label: "Limit",
                                          amount: $creditLimit,
                                          currencySymbol: currencySymbol)
                    }

                    Section {
                        Picker(String(localized: "Adjust by"), selection: $creditInputMode) {
                            ForEach(CreditBalanceInputMode.allCases) { mode in
                                Text(mode.displayName).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: creditInputMode) { _, newMode in
                            syncCreditInputMode(to: newMode)
                        }

                        if creditInputMode == .available {
                            CurrencyFormField(label: "Available Balance",
                                              amount: $creditAvailable,
                                              currencySymbol: currencySymbol)
                        } else {
                            CurrencyFormField(label: "Current Consumed",
                                              amount: $creditConsumed,
                                              currencySymbol: currencySymbol)
                        }

                        VStack(spacing: 6) {
                            HStack {
                                Text(String(localized: "Consumed"))
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(calculatedConsumed, format: .currency(code: currencyCode))
                                    .font(.subheadline.bold())
                            }
                            HStack {
                                Text(String(localized: "Available Balance"))
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(calculatedAvailable, format: .currency(code: currencyCode))
                                    .font(.subheadline.bold())
                                    .foregroundColor(calculatedAvailable < 0 ? .red : .primary)
                            }
                        }
                        .padding(.top, 4)
                    } header: {
                        Text(String(localized: "Current Balance"))
                    } footer: {
                        Text(String(localized: "Enter your current available credit or consumed balance. New expenses assigned to this card will automatically update it."))
                    }
                } else {
                    Section(String(localized: "Opening Balance")) {
                        CurrencyFormField(label: "Balance",
                                          amount: $initialBalance,
                                          currencySymbol: currencySymbol)
                    }
                }

                if isCredit {
                    Section {
                        Stepper(value: $cutDay, in: 1...31) {
                            HStack {
                                Text(String(localized: "Cut Day"))
                                Spacer()
                                Text("\(cutDay)")
                                    .foregroundColor(.secondary)
                                    .monospacedDigit()
                            }
                        }
                        Stepper(value: $graceDays, in: 0...60) {
                            HStack {
                                Text(String(localized: "Days to Pay"))
                                Spacer()
                                Text("\(graceDays)")
                                    .foregroundColor(.secondary)
                                    .monospacedDigit()
                            }
                        }
                    } footer: {
                        Text(String(localized: "Payment date is calculated from the cut day plus the days to pay."))
                    }

                    Section(String(localized: "Preview")) {
                        VStack(alignment: .leading, spacing: 6) {
                            previewRow(String(localized: "Next Cut"),
                                       previewAccount.nextCut().formatted(.dateTime.month().day()))
                            previewRow(String(localized: "Payment Date"),
                                       previewAccount.nextPaymentDate().formatted(.dateTime.month().day()))
                        }
                    }
                }

                if account != nil {
                    Section {
                        Button(role: .destructive) {
                            deleteAccount()
                        } label: {
                            HStack {
                                Spacer()
                                Label(String(localized: "Delete Account"), systemImage: "trash")
                                Spacer()
                            }
                        }
                    }
                }
            }
            .navigationTitle(account == nil ? String(localized: "New Account") : String(localized: "Edit Account"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "Save")) { save() }
                        .fontWeight(.semibold)
                }
            }
            .onAppear(perform: populate)
            .alert(String(localized: "Error"), isPresented: $showingValidationAlert) {
                Button(String(localized: "OK"), role: .cancel) {}
            } message: {
                Text(validationMessage)
            }
        }
    }

    // MARK: - Helpers

    private func syncCreditInputMode(to newMode: CreditBalanceInputMode) {
        switch newMode {
        case .available:
            let consumed = Double(creditConsumed) ?? 0
            let avail = max(0, limitValue - consumed)
            creditAvailable = limitValue > 0 || consumed > 0 ? String(format: "%g", avail) : ""
        case .consumed:
            if !creditAvailable.isEmpty {
                let avail = Double(creditAvailable) ?? 0
                let consumed = max(0, limitValue - avail)
                creditConsumed = consumed > 0 ? String(format: "%g", consumed) : ""
            }
        }
    }

    private func previewRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title).font(.subheadline).foregroundColor(.secondary)
            Spacer()
            Text(value).font(.subheadline.bold())
        }
    }

    /// A throw-away account built from the current form values, used for the date preview.
    private var previewAccount: Account {
        Account(
            id: account?.id ?? UUID(),
            name: name.isEmpty ? "Preview" : name,
            type: type,
            creditLimit: limitValue,
            initialBalance: Double(initialBalance) ?? 0,
            cutDay: cutDay,
            graceDays: graceDays
        )
    }

    private func populate() {
        guard let account = account else { return }
        name = account.name
        type = account.type
        creditLimit = account.creditLimit > 0 ? String(format: "%g", account.creditLimit) : ""
        cutDay = account.cutDay
        graceDays = account.graceDays

        if account.type == .credit {
            let expenses = StorageService.loadExpenses()
            let currentConsumed = account.consumed(expenses: expenses)
            let currentAvailable = account.availableBalance(expenses: expenses)
            creditConsumed = currentConsumed > 0 ? String(format: "%g", currentConsumed) : ""
            creditAvailable = account.creditLimit > 0 || currentConsumed > 0
                ? String(format: "%g", currentAvailable)
                : ""
        } else {
            initialBalance = account.initialBalance > 0 ? String(format: "%g", account.initialBalance) : ""
        }
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            validationMessage = String(localized: "Account name is required")
            showingValidationAlert = true
            return
        }

        var accounts = AccountStorage.load()
        let limit = limitValue
        let debitBalance = Double(initialBalance) ?? 0

        // For credit accounts, compute the base adjustment so that
        // (initialBalance + cycleTransactionsConsumed) equals the user's entered consumed balance.
        let targetAccountID = account?.id ?? UUID()
        var tempCreditAccount = Account(
            id: targetAccountID,
            name: trimmed,
            type: type,
            creditLimit: limit,
            initialBalance: 0,
            cutDay: cutDay,
            graceDays: graceDays
        )
        let expenses = StorageService.loadExpenses()
        let cycleTx = type == .credit ? tempCreditAccount.cycleTransactionsConsumed(expenses: expenses) : 0
        let creditBaseAdjustment = calculatedConsumed - cycleTx
        tempCreditAccount.initialBalance = type == .credit ? creditBaseAdjustment : debitBalance

        if var existing = account, let index = accounts.firstIndex(where: { $0.id == existing.id }) {
            existing.name = trimmed
            existing.type = type
            existing.creditLimit = type == .credit ? limit : 0
            existing.initialBalance = type == .credit ? creditBaseAdjustment : debitBalance
            existing.cutDay = cutDay
            existing.graceDays = graceDays
            accounts[index] = existing
        } else {
            accounts.append(tempCreditAccount)
        }

        AccountStorage.save(accounts)
        onSave?()
        dismiss()
    }

    private func deleteAccount() {
        guard let account = account else { return }
        var accounts = AccountStorage.load()
        accounts.removeAll { $0.id == account.id }
        AccountStorage.save(accounts)
        onSave?()
        dismiss()
    }
}

#Preview {
    AccountFormView(account: nil)
        .environmentObject(SettingsViewModel())
}
