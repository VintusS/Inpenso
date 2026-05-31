//
//  AddExpenseView.swift
//  iExpense
//
//  Created by Dragomir Mindrescu on 27.04.2025.
//

import SwiftUI

struct AddExpenseView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject private var settingsViewModel: SettingsViewModel
    @EnvironmentObject private var categoryStore: CategoryStore
    @ObservedObject var viewModel: ExpenseViewModel
    
    // Form fields
    @State private var title: String = ""
    @State private var price: String = ""
    @State private var selectedCategoryID: String
    @State private var transactionType: TransactionType = .expense
    @State private var selectedDate: Date = Date()
    @State private var notes: String = ""
    
    // UI States
    @State private var showDatePicker = false
    @State private var keyboardVisible: Bool = false
    @State private var showingValidationAlert = false
    @State private var validationMessage = ""
    @State private var animateSuccess = false
    
    // Current currency symbol
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
        NavigationView {
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
                                categories: categoryStore.allCategories
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
                        if #available(iOS 26.0, *) {
                            saveButton
                                .glassEffect(isFormValid() ? .regular.tint(.blue).interactive() : .regular.tint(.gray))
                        } else {
                            saveButton
                                .background(isFormValid() ? Color.accentColor : Color.gray)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                        }
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
                withAnimation {
                    keyboardVisible = true
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
                withAnimation {
                    keyboardVisible = false
                }
            }
            .alert(validationMessage, isPresented: $showingValidationAlert) {
                Button("OK", role: .cancel) { }
            }
            .onAppear {
                selectedCategoryID = categoryStore.preferredCategoryID(for: selectedCategoryID)
            }
        }
    }
    
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
                    placeholder: transactionType == .expense ? "Expense title" : "Income title",
                    leadingIcon: "pencil"
                )
                .padding(.horizontal)
                
                // Price field
                CurrencyFormField(
                    label: "Amount",
                    amount: $price,
                    currencySymbol: currencySymbol,
                    clearAction: { price = "" }
                )
                .padding(.horizontal)
                .padding(.bottom, 8)
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
            HStack {
                Spacer()
                Text("Save Transaction")
                Spacer()
            }
            .padding()
            .foregroundColor(.white)
            
//            HStack {
//                Spacer()
//                Text("Save Expense")
//                    .fontWeight(.bold)
//                Spacer()
//            }
//            .padding()
//            .background(isFormValid() ? Color.accentColor : Color.gray)
//            .foregroundColor(.white)
//            .cornerRadius(16)
        }
        .disabled(!isFormValid())
    }
    
//    let saveButton: some View =
//    
//    if #available(iOS 26.0, *) {
//        saveButton
//            .glassEffect(.regular.tint(.blue).interactive())
//    } else {
//        saveButton
//            .background(Color.blue.opacity(0.8))
//            .cornerRadius(12)
//    }
    
    // MARK: - Success Overlay
    
    private var successOverlay: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.green)
                
                Text("Transaction Added!")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
            }
            .padding(30)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(.systemBackground).opacity(0.8))
                    .blur(radius: 0.5)
            )
            .scaleEffect(animateSuccess ? 1.0 : 0.5)
            .opacity(animateSuccess ? 1.0 : 0)
            .animation(.spring(), value: animateSuccess)
        }
    }
    
    // MARK: - Helper Methods
    
    private func isFormValid() -> Bool {
        return !title.isEmpty && !price.isEmpty
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
        
        price = price.replacingOccurrences(of: ",", with: ".")
        guard let priceValue = Double(price) else {
            showValidationAlert("Please enter a valid amount.")
            return
        }
        
        // Show success animation
        withAnimation {
            animateSuccess = true
        }
        
        let selectedCategory = categoryStore.category(for: selectedCategoryID)
        let legacyCategory = Category.category(from: selectedCategory.id) ?? .others
        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)

        // Add the transaction with all fields
        _ = viewModel.addExpense(
            title: title,
            price: priceValue,
            date: selectedDate,
            category: legacyCategory,
            type: transactionType,
            categoryID: selectedCategory.id,
            notes: trimmedNotes.isEmpty ? nil : trimmedNotes
        )
        
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
        .environmentObject(CategoryStore())
}
