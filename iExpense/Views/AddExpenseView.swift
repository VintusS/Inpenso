//
//  AddExpenseView.swift
//  iExpense
//
//  Created by Dragomir Mindrescu on 27.04.2025.
//

import SwiftUI

struct AddExpenseView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.locale) private var locale
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject private var settingsViewModel: SettingsViewModel
    @EnvironmentObject private var walletsViewModel: WalletsViewModel
    @EnvironmentObject private var categoryStore: CategoryStore
    @ObservedObject var viewModel: ExpenseViewModel
    
    // Form fields
    @State private var title: String = ""
    @State private var price: String = ""
    @State private var selectedCategoryID: String
    @State private var transactionType: TransactionType = .expense
    @State private var selectedDate: Date = Date()
    @State private var notes: String = ""
    @State private var walletID: UUID? = WalletService.defaultWalletID()
    @State private var refundOfID: UUID?
    @State private var instalment = InstalmentChoice()
    
    // UI States
    @State private var showDatePicker = false
    @State private var keyboardVisible: Bool = false
    @State private var showingValidationAlert = false
    @State private var validationMessage = ""
    @State private var animateSuccess = false
    
    // Current currency symbol
    private var amountInput: AmountInput {
        AmountInput(fractionDigits: currencyFractionDigits(for: settingsViewModel.selectedCurrency), locale: locale)
    }

    private var currencySymbol: String {
        let locale = Locale.current
        let currencyCode = settingsViewModel.selectedCurrency
        return locale.localizedCurrencySymbol(forCurrencyCode: currencyCode) ?? currencyCode
    }
    
    init(viewModel: ExpenseViewModel) {
        self.viewModel = viewModel
        // Initialize with the default category from settings
        let defaultCategoryID = UserDefaults.standard.string(forKey: "defaultCategoryID") ?? Category.food.categoryID
        _selectedCategoryID = State(initialValue: defaultCategoryID)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Title and amount card
                        mainDataCard
                        
                        // Category selection
                        CardView(title: "Category") {
                            CategoryGrid(
                                selectedCategoryID: $selectedCategoryID,
                                categories: categoryStore.categoriesForPicker(kind: transactionType.categoryKind)
                            )
                                .padding(.horizontal)
                        }
                        
                        // Date selection
                        DatePickerCard(
                            title: "Date",
                            selectedDate: $selectedDate,
                            isExpanded: $showDatePicker
                        )
                        
                        // Notes
                        notesCard
                        
                        // Save Button
                        saveButton
                    }
                    .padding(.horizontal)
                    .padding(.top, 10)
                    .padding(.bottom, 24)
                }
                .scrollDismissesKeyboard(.interactively)
                
                // Success animation overlay
                if animateSuccess {
                    successOverlay
                }
            }
            .navigationTitle("Add Transaction")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                // Done button only shows when keyboard is visible
                ToolbarItem(placement: .navigationBarTrailing) {
                    if keyboardVisible {
                        Button("Done") {
                            hideKeyboard()
                        }
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
                withAnimation(reduceMotion ? nil : .default) {
                    keyboardVisible = true
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
                withAnimation(reduceMotion ? nil : .default) {
                    keyboardVisible = false
                }
            }
            .alert(validationMessage, isPresented: $showingValidationAlert) {
                Button("OK", role: .cancel) { }
            }
            .onAppear {
                selectedCategoryID = categoryStore.preferredCategoryID(for: selectedCategoryID, kind: transactionType.categoryKind)
            }
            .onChange(of: transactionType) { _, newType in
                selectedCategoryID = categoryStore.preferredCategoryID(for: selectedCategoryID, kind: newType.categoryKind)
            }
            .onChange(of: refundOfID) { _, purchaseID in
                if let purchase = viewModel.expenses.first(where: { $0.id == purchaseID }) {
                    selectedCategoryID = purchase.categoryID
                }
            }
        }
    }
}

// MARK: - Sections

extension AddExpenseView {
    // MARK: - Main Data Card

    private var mainDataCard: some View {
        CardView(title: "Transaction Details", showDivider: true) {
            VStack(spacing: 16) {
                Picker("Type", selection: $transactionType) {
                    ForEach(TransactionType.allCases) { type in
                        Text(type.displayName).tag(type)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                // Title field
                TextFormField(
                    label: "Title",
                    text: $title,
                    placeholder: transactionType.titlePlaceholder,
                    leadingIcon: "pencil"
                )
                .padding(.horizontal)
                
                // Price field
                CurrencyFormField(
                    label: "Amount",
                    amount: $price,
                    currencySymbol: currencySymbol,
                    fractionDigits: amountInput.fractionDigits,
                    clearAction: { price = "" }
                )
                .padding(.horizontal)

                WalletFormField(selection: $walletID, wallets: walletsViewModel.wallets)
                    .padding(.horizontal)
                    .padding(.bottom, transactionType == .refund ? 0 : 8)

                if showsInstalmentFields {
                    InstalmentFields(
                        choice: $instalment,
                        principal: amountInput.value(of: price),
                        input: amountInput,
                        currency: settingsViewModel.selectedCurrency,
                        payFromWallets: walletsViewModel.activeWallets.filter { !$0.kind.isCredit }
                    )
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                    .transition(.opacity)
                }

                if transactionType == .refund {
                    RefundLinkField(
                        selection: $refundOfID,
                        purchases: RefundLinkField.candidates(in: viewModel.expenses, refundDate: selectedDate, linkedID: refundOfID),
                        currencyCode: settingsViewModel.selectedCurrency
                    )
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                }
            }
        }
    }
    
    // MARK: - Notes Card
    
    private var notesCard: some View {
        CardView(title: "Notes (Optional)") {
            ZStack(alignment: .topLeading) {
                // Background that adapts to color scheme
                RoundedRectangle(cornerRadius: 10)
                    .fill(colorScheme == .dark ? Color(.systemGray6) : Color(.systemBackground))
                    .frame(minHeight: 100)
                
                // Text editor
                TextEditor(text: $notes)
                    .font(.body)
                    .scrollContentBackground(.hidden) // Hide the default background
                    .background(Color.clear) // Use transparent background
                    .padding(8)
                    .frame(minHeight: 100)
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
    }
    
    // MARK: - Save Button
    
    private var saveButton: some View {
        Button(action: saveExpense) {
            Text("Save Transaction")
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.borderedProminent)
        .disabled(!isFormValid())
    }

    // MARK: - Success Overlay
    
    private var successOverlay: some View {
        ZStack {
            Color(.systemBackground).opacity(reduceTransparency ? 1 : 0.6)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.largeTitle)
                    .foregroundColor(.green)
                
                Text("Transaction Added!")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
            }
            .padding(30)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
            .scaleEffect(reduceMotion || animateSuccess ? 1 : 0.5)
            .opacity(animateSuccess ? 1.0 : 0)
            .animation(reduceMotion ? nil : .spring(), value: animateSuccess)
        }
    }
    
    // MARK: - Helper Methods
    
    /// Instalments only apply to a purchase on a credit card or paylater wallet.
    private var showsInstalmentFields: Bool {
        transactionType == .expense && walletsViewModel.wallet(for: walletID)?.kind.isCredit == true
    }

    private func isFormValid() -> Bool {
        !title.isEmpty && !price.isEmpty
    }
    
    private func saveExpense() {
        // Hide keyboard first
        hideKeyboard()
        
        // Validate inputs
        if title.isEmpty {
            showValidationAlert("Please enter a title.")
            return
        }
        
        if price.isEmpty {
            showValidationAlert("Please enter an amount.")
            return
        }
        
        guard let priceValue = amountInput.value(of: price) else {
            showValidationAlert("Please enter a valid amount.")
            return
        }
        
        let selectedCategory = categoryStore.category(for: selectedCategoryID)
        let legacyCategory = Category.category(from: selectedCategory.id) ?? .others
        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)

        // Keep the form open with the user's input if the save fails.
        do {
            if showsInstalmentFields && instalment.isOn {
                let purchase = Expense(
                    title: title,
                    price: priceValue,
                    date: selectedDate,
                    category: legacyCategory,
                    type: .expense,
                    categoryID: selectedCategory.id,
                    notes: trimmedNotes.isEmpty ? nil : trimmedNotes,
                    walletID: walletID
                )
                try viewModel.addCreditPurchase(
                    purchase,
                    instalment: (
                        months: instalment.months,
                        monthlyFee: amountInput.value(of: instalment.monthlyFeeText) ?? 0,
                        payFromWalletID: instalment.payFromWalletID
                    )
                )
                walletsViewModel.refresh()
            } else {
                _ = try viewModel.addExpense(
                    title: title,
                    price: priceValue,
                    date: selectedDate,
                    category: legacyCategory,
                    type: transactionType,
                    categoryID: selectedCategory.id,
                    notes: trimmedNotes.isEmpty ? nil : trimmedNotes,
                    walletID: walletID,
                    refundOfID: refundOfID
                )
            }
        } catch WalletError.unknownWallet {
            showValidationAlert("That wallet is no longer available. Choose another wallet.")
            return
        } catch {
            showValidationAlert("Couldn't save the transaction. Please try again.")
            return
        }

        withAnimation(reduceMotion ? nil : .default) {
            animateSuccess = true
        }

        // Trigger success haptic
        HapticFeedback.success()
        
        // Wait for animation, then dismiss
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            dismiss()
        }
    }
    
    private func showValidationAlert(_ message: String) {
        validationMessage = message
        showingValidationAlert = true
        HapticFeedback.error()
    }
    
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

// MARK: - Locale Extension

extension Locale {
    func localizedCurrencySymbol(forCurrencyCode currencyCode: String) -> String? {
        let identifier = NSLocale(localeIdentifier: self.identifier).displayName(forKey: .currencySymbol, value: currencyCode)
        return identifier
    }
}

#Preview {
    AddExpenseView(viewModel: ExpenseViewModel())
        .environmentObject(SettingsViewModel())
        .environmentObject(WalletsViewModel())
        .environmentObject(CategoryStore())
}
