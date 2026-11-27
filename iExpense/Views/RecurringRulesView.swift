//
//  RecurringRulesView.swift
//  iExpense
//

import SwiftUI

/// Lists monthly recurring rules (salary, rent, subscriptions) and edits them.
struct RecurringRulesView: View {
    @ObservedObject var recurringViewModel: RecurringViewModel
    @EnvironmentObject private var settingsViewModel: SettingsViewModel
    @EnvironmentObject private var categoryStore: CategoryStore
    @State private var editingRule: RecurringRule?

    var body: some View {
        List {
            if recurringViewModel.rules.isEmpty {
                Section {
                    VStack(spacing: 8) {
                        Image(systemName: "repeat")
                            .font(.title)
                            .foregroundColor(.secondary)
                        Text("No recurring transactions")
                            .font(.headline)
                        Text("Add your salary, rent or subscriptions once. Each month they show up on Home for you to confirm.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical)
                }
            }

            ForEach(TransactionType.allCases) { type in
                let rules = recurringViewModel.rules.filter { $0.type == type }
                if !rules.isEmpty {
                    Section(type == .income ? "Income" : "Expenses") {
                        ForEach(rules) { rule in
                            Button {
                                editingRule = rule
                            } label: {
                                row(for: rule)
                            }
                        }
                        .onDelete { offsets in
                            offsets.map { rules[$0] }.forEach(recurringViewModel.delete)
                        }
                    }
                }
            }
        }
        .navigationTitle("Recurring")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    editingRule = RecurringRule(
                        title: "",
                        amount: 0,
                        type: .income,
                        categoryID: categoryStore.preferredCategoryID(for: nil),
                        dayOfMonth: Calendar.current.component(.day, from: Date()),
                        startDate: Calendar.current.startOfDay(for: Date())
                    )
                } label: {
                    Label("Add", systemImage: "plus")
                }
            }
        }
        .sheet(item: $editingRule) { rule in
            RecurringRuleEditor(
                rule: rule,
                isNew: !recurringViewModel.rules.contains { $0.id == rule.id },
                onSave: { recurringViewModel.save($0) },
                onDelete: { recurringViewModel.delete($0) }
            )
        }
    }

    private func row(for rule: RecurringRule) -> some View {
        let category = categoryStore.category(for: rule.categoryID)
        return HStack(spacing: 12) {
            Image(systemName: category.iconName)
                .font(.system(size: 14))
                .foregroundColor(.white)
                .frame(width: 28, height: 28)
                .background(category.color)
                .cornerRadius(6)

            VStack(alignment: .leading, spacing: 2) {
                Text(rule.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                Text(rule.isActive ? "Every month on day \(rule.dayOfMonth)" : "Paused")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Text(rule.amount, format: .currency(code: settingsViewModel.selectedCurrency))
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(rule.isActive ? rule.type.amountColor : .secondary)
        }
    }
}

struct RecurringRuleEditor: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @EnvironmentObject private var settingsViewModel: SettingsViewModel
    @EnvironmentObject private var categoryStore: CategoryStore
    @EnvironmentObject private var walletsViewModel: WalletsViewModel

    @State private var rule: RecurringRule
    @State private var amountText: String
    @State private var showingDeleteConfirmation = false
    let isNew: Bool
    let onSave: (RecurringRule) -> Void
    let onDelete: (RecurringRule) -> Void

    init(rule: RecurringRule, isNew: Bool, onSave: @escaping (RecurringRule) -> Void, onDelete: @escaping (RecurringRule) -> Void) {
        _rule = State(initialValue: rule)
        _amountText = State(initialValue: "")
        self.isNew = isNew
        self.onSave = onSave
        self.onDelete = onDelete
    }

    private var amountInput: AmountInput {
        AmountInput(fractionDigits: currencyFractionDigits(for: settingsViewModel.selectedCurrency), locale: locale)
    }

    private var amountValue: Double? {
        amountInput.value(of: amountText)
    }

    private var canSave: Bool {
        !rule.title.trimmingCharacters(in: .whitespaces).isEmpty && (amountValue ?? 0) > 0
    }

    var body: some View {
        NavigationView {
            Form {
                Section {
                    Picker("Type", selection: $rule.type) {
                        ForEach(TransactionType.allCases) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)

                    TextField("Title, e.g. Salary", text: $rule.title)

                    CurrencyFormField(
                        label: "Amount",
                        amount: $amountText,
                        currencySymbol: locale.localizedCurrencySymbol(forCurrencyCode: settingsViewModel.selectedCurrency)
                            ?? settingsViewModel.selectedCurrency,
                        fractionDigits: amountInput.fractionDigits
                    )
                    .listRowInsets(EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8))

                    WalletPicker(
                        title: "Wallet",
                        selection: Binding(get: { rule.walletID ?? walletsViewModel.defaultWalletID }, set: { rule.walletID = $0 }),
                        wallets: walletsViewModel.wallets,
                        including: rule.walletID
                    )

                    Picker("Category", selection: $rule.categoryID) {
                        ForEach(categoryStore.categoriesForPicker(including: rule.categoryID)) { category in
                            Label(category.displayName, systemImage: category.iconName).tag(category.id)
                        }
                    }
                }

                Section {
                    Stepper("Day \(rule.dayOfMonth) of each month", value: $rule.dayOfMonth, in: 1...31)
                    DatePicker("Starts", selection: $rule.startDate, displayedComponents: .date)
                    Toggle("Active", isOn: $rule.isActive)
                } footer: {
                    Text(rule.dayOfMonth > 28
                         ? "In months with fewer than \(rule.dayOfMonth) days, it falls on the last day of the month."
                         : "Due items appear on Home for you to add or skip.")
                }

                Section("Notes") {
                    TextField("Optional", text: Binding(
                        get: { rule.notes ?? "" },
                        set: { rule.notes = $0.isEmpty ? nil : $0 }
                    ), axis: .vertical)
                }

                if !isNew {
                    Section {
                        Button("Delete Recurring Transaction", role: .destructive) {
                            showingDeleteConfirmation = true
                        }
                    } footer: {
                        Text("Transactions already added stay in your history.")
                    }
                }
            }
            .navigationTitle(isNew ? "New Recurring" : "Edit Recurring")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        var saved = rule
                        saved.title = saved.title.trimmingCharacters(in: .whitespaces)
                        saved.amount = amountValue ?? 0
                        onSave(saved)
                        dismiss()
                    }
                    .disabled(!canSave)
                }
            }
            .confirmationDialog("Delete this recurring transaction?", isPresented: $showingDeleteConfirmation, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    onDelete(rule)
                    dismiss()
                }
            }
            .onAppear {
                if amountText.isEmpty && rule.amount > 0 {
                    amountText = amountInput.bindingText(for: rule.amount)
                }
            }
        }
    }
}
