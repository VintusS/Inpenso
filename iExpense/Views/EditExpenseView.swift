//
//  EditExpenseView.swift
//  iExpense
//
//  Created by Dragomir Mindrescu on 27.04.2025.
//

import SwiftUI

struct EditExpenseView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject private var settingsViewModel: SettingsViewModel
    @EnvironmentObject private var categoryStore: CategoryStore
    @ObservedObject var viewModel: ExpenseViewModel

    @State private var title: String
    @State private var price: String
    @State private var selectedDate: Date
    @State private var selectedCategoryID: String
    @State private var transactionType: TransactionType
    @State private var showDatePicker: Bool = false
    @State private var notes: String = ""
    @State private var keyboardVisible: Bool = false
    @State private var viewID = UUID()
    let expense: Expense

    init(viewModel: ExpenseViewModel, expense: Expense) {
        self.viewModel = viewModel
        self.expense = expense
        _title = State(initialValue: expense.title)
        _price = State(initialValue: String(format: "%.2f", expense.price))
        _selectedDate = State(initialValue: expense.date)
        _selectedCategoryID = State(initialValue: expense.categoryID)
        _transactionType = State(initialValue: expense.type)
        _notes = State(initialValue: expense.notes ?? "")
    }

    // Current currency symbol
    private var currencySymbol: String {
        let locale = Locale.current
        let currencyCode = settingsViewModel.selectedCurrency
        return locale.localizedCurrencySymbol(forCurrencyCode: currencyCode) ?? currencyCode
    }

    var body: some View {
        NavigationView {
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
                                    placeholder: transactionType == .expense ? "Expense title" : "Income title"
                                )
                                .padding(.horizontal)
                                
                                CurrencyFormField(
                                    label: "Amount",
                                    amount: $price,
                                    currencySymbol: currencySymbol
                                )
                                .padding(.horizontal)
                                .padding(.bottom, 8)
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
                                categories: categoryStore.categoriesForPicker(including: selectedCategoryID)
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
                            Button(action: {
                                hideKeyboard()
                                saveChanges()
                                HapticFeedback.success()
                                dismiss()
                            }) {
                                let saveButton: some View = HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                    Text("Save Changes")
                                }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .foregroundColor(.white)
                                    .cornerRadius(12)
                                
                                if #available(iOS 26.0, *) {
                                    saveButton
                                        .glassEffect(.regular.tint(.blue).interactive())
                                } else {
                                    saveButton
                                        .background(Color.blue.opacity(0.8))
                                        .cornerRadius(12)
                                }
                            }
                            
                            Button(action: {
                                hideKeyboard()
                                deleteExpense()
                                HapticFeedback.impact(style: .medium)
                                dismiss()
                            }) {
                                let deleteButton: some View = HStack {
                                    Image(systemName: "trash.fill")
                                    Text("Delete Transaction")
                                }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .foregroundColor(.white)
                                    .cornerRadius(12)
                                if #available(iOS 26.0, *) {
                                    deleteButton
                                        .glassEffect(.regular.tint(.red).interactive())
                                } else {
                                    deleteButton
                                        .background(Color.red.opacity(0.8))
                                        .cornerRadius(12)
                                }
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
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
                withAnimation {
                    keyboardVisible = true
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
                withAnimation {
                    keyboardVisible = false
                }
            }
        }
    }

    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    private func saveChanges() {
        guard let priceValue = Double(price.replacingOccurrences(of: ",", with: ".")) else { return }
        
        if let index = viewModel.expenses.firstIndex(where: { $0.id == expense.id }) {
            let selectedCategory = categoryStore.category(for: selectedCategoryID)
            viewModel.expenses[index].title = title
            viewModel.expenses[index].price = priceValue
            viewModel.expenses[index].date = selectedDate
            viewModel.expenses[index].type = transactionType
            viewModel.expenses[index].categoryID = selectedCategory.id
            viewModel.expenses[index].category = Category.category(from: selectedCategory.id) ?? .others
            let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
            viewModel.expenses[index].notes = trimmedNotes.isEmpty ? nil : trimmedNotes
            viewModel.saveExpenses()
        }
    }

    private func deleteExpense() {
        if let index = viewModel.expenses.firstIndex(where: { $0.id == expense.id }) {
            viewModel.expenses.remove(at: index)
            viewModel.saveExpenses()
        }
    }
}

#Preview {
    EditExpenseView(viewModel: ExpenseViewModel(), expense: Expense(title: "Sample", price: 10, date: Date(), category: .food))
        .environmentObject(SettingsViewModel())
        .environmentObject(CategoryStore())
}
