//
//  EditExpenseView.swift
//  iExpense
//
//  Created by Dragomir Mindrescu on 27.04.2025.
//

import SwiftUI

struct EditExpenseView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.locale) private var locale
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject private var settingsViewModel: SettingsViewModel
    @EnvironmentObject private var walletsViewModel: WalletsViewModel
    @EnvironmentObject private var categoryStore: CategoryStore
    @ObservedObject var viewModel: ExpenseViewModel

    @State private var title: String
    @State private var priceDraft: String?
    @State private var selectedDate: Date
    @State private var selectedCategoryID: String
    @State private var transactionType: TransactionType
    @State private var showDatePicker: Bool = false
    @State private var notes: String = ""
    @State private var walletID: UUID?
    @State private var refundOfID: UUID?
    @State private var keyboardVisible: Bool = false
    @State private var viewID = UUID()
    let expense: Expense

    init(viewModel: ExpenseViewModel, expense: Expense) {
        self.viewModel = viewModel
        self.expense = expense
        _title = State(initialValue: expense.title)
        _selectedDate = State(initialValue: expense.date)
        _selectedCategoryID = State(initialValue: expense.categoryID)
        _transactionType = State(initialValue: expense.type)
        _notes = State(initialValue: expense.notes ?? "")
        _walletID = State(initialValue: expense.walletID)
        _refundOfID = State(initialValue: expense.refundOfID)
    }

    // Current currency symbol
    private var amountInput: AmountInput {
        AmountInput(fractionDigits: currencyFractionDigits(for: settingsViewModel.selectedCurrency), locale: locale)
    }

    private var price: Binding<String> {
        Binding(
            get: { priceDraft ?? amountInput.bindingText(for: expense.price) },
            set: { priceDraft = $0 }
        )
    }

    private var priceValue: Double? {
        if let priceDraft {
            return amountInput.value(of: priceDraft)
        }
        return expense.price
    }

    private var currencySymbol: String {
        let locale = Locale.current
        let currencyCode = settingsViewModel.selectedCurrency
        return locale.localizedCurrencySymbol(forCurrencyCode: currencyCode) ?? currencyCode
    }

    @State private var showingDeleteConfirmation = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Title and price card
                        CardView(title: "Transaction Details", showDivider: true) {
                            VStack(spacing: 16) {
                                Picker("Type", selection: $transactionType) {
                                    ForEach(TransactionType.allCases) { type in
                                        Text(type.displayName).tag(type)
                                    }
                                }
                                .pickerStyle(.segmented)
                                .padding(.horizontal)

                                TextFormField(
                                    label: "Title",
                                    text: $title,
                                    placeholder: transactionType.titlePlaceholder
                                )
                                .padding(.horizontal)
                                
                                CurrencyFormField(
                                    label: "Amount",
                                    amount: price,
                                    currencySymbol: currencySymbol,
                                    fractionDigits: amountInput.fractionDigits
                                )
                                .padding(.horizontal)

                                WalletFormField(selection: $walletID, wallets: walletsViewModel.wallets, including: expense.walletID)
                                    .padding(.horizontal)
                                    .padding(.bottom, transactionType == .refund ? 0 : 8)

                                if transactionType == .refund {
                                    RefundLinkField(
                                        selection: $refundOfID,
                                        purchases: RefundLinkField.candidates(
                                            in: viewModel.expenses.filter { $0.id != expense.id },
                                            refundDate: selectedDate,
                                            linkedID: refundOfID
                                        ),
                                        currencyCode: settingsViewModel.selectedCurrency
                                    )
                                    .padding(.horizontal)
                                    .padding(.bottom, 8)
                                }
                            }
                        }
                        
                        // Date picker
                        DatePickerCard(
                            title: "Date",
                            selectedDate: $selectedDate,
                            isExpanded: $showDatePicker
                        )
                        
                        // Category selection
                        CardView(title: "Category") {
                            CategoryGrid(
                                selectedCategoryID: $selectedCategoryID,
                                categories: categoryStore.categoriesForPicker(
                                    kind: transactionType.categoryKind,
                                    including: transactionType.categoryKind == expense.type.categoryKind ? expense.categoryID : nil
                                )
                            )
                                .padding(.horizontal)
                        }
                        
                        // Notes section with improved appearance
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
                        
                        // Action buttons
                        VStack(spacing: 12) {
                            Button {
                                guard priceValue != nil else { return }
                                hideKeyboard()
                                saveChanges()
                                HapticFeedback.success()
                                dismiss()
                            } label: {
                                Label("Save Changes", systemImage: "checkmark.circle.fill")
                                    .frame(maxWidth: .infinity, minHeight: 44)
                            }
                            .buttonStyle(.borderedProminent)

                            Button(role: .destructive) {
                                hideKeyboard()
                                showingDeleteConfirmation = true
                            } label: {
                                Label("Delete Transaction", systemImage: "trash.fill")
                                    .frame(maxWidth: .infinity, minHeight: 44)
                            }
                            .buttonStyle(.bordered)
                            .confirmationDialog(
                                "Delete this transaction?",
                                isPresented: $showingDeleteConfirmation,
                                titleVisibility: .visible
                            ) {
                                Button("Delete Transaction", role: .destructive) {
                                    deleteExpense()
                                    HapticFeedback.impact(style: .medium)
                                    dismiss()
                                }
                                Button("Cancel", role: .cancel) {}
                            }
                        }
                        .padding(.top, 10)
                    }
                    .padding()
                    .padding(.bottom, 24)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .id(viewID)
            .navigationTitle("Edit Transaction")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // Cancel button
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
            .onAppear {
                viewID = UUID()
            }
            .onChange(of: transactionType) { _, newType in
                if newType.categoryKind != categoryStore.category(for: selectedCategoryID).kind {
                    selectedCategoryID = categoryStore.preferredCategoryID(for: nil, kind: newType.categoryKind)
                }
            }
            .onChange(of: refundOfID) { _, purchaseID in
                if let purchase = viewModel.expenses.first(where: { $0.id == purchaseID }) {
                    selectedCategoryID = purchase.categoryID
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
        }
    }

    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    private func saveChanges() {
        guard let priceValue else { return }
        
        let selectedCategory = categoryStore.category(for: selectedCategoryID)
        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        viewModel.updateExpense(id: expense.id) { transaction in
            transaction.title = title
            if priceDraft != nil { transaction.price = priceValue }
            transaction.date = selectedDate
            transaction.type = transactionType
            transaction.categoryID = selectedCategory.id
            transaction.category = Category.category(from: selectedCategory.id) ?? .others
            transaction.notes = trimmedNotes.isEmpty ? nil : trimmedNotes
            transaction.walletID = walletID
            transaction.refundOfID = transactionType == .refund ? refundOfID : nil
        }
    }

    private func deleteExpense() {
        viewModel.deleteExpenses([expense])
    }
}

#Preview {
    EditExpenseView(viewModel: ExpenseViewModel(), expense: Expense(title: "Sample", price: 10, date: Date(), category: .food))
        .environmentObject(SettingsViewModel())
        .environmentObject(WalletsViewModel())
        .environmentObject(CategoryStore())
}
