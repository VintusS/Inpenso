//
//  AddExpenseView.swift
//  iExpense
//
//  Created by Dragomir Mindrescu on 27.04.2025.
//

import SwiftUI

struct AddExpenseView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var viewModel: ExpenseViewModel
    @StateObject private var settingsViewModel = SettingsViewModel()
    
    // Form fields
    @State private var title: String = ""
    @State private var price: String = ""
    @State private var selectedCategory: Category
    @State private var selectedDate: Date = Date()
    @State private var notes: String = ""
    
    // UI States
    @State private var showDatePicker = false
    @State private var keyboardHeight: CGFloat = 0
    @State private var showingValidationAlert = false
    @State private var validationMessage = ""
    @State private var animateSuccess = false
    
    // Current currency symbol
    private var currencySymbol: String {
        let locale = Locale.current
        let currencyCode = SettingsViewModel.getAppCurrency()
        return locale.localizedCurrencySymbol(forCurrencyCode: currencyCode) ?? currencyCode
    }
    
    init(viewModel: ExpenseViewModel) {
        self.viewModel = viewModel
        // Initialize with the default category from settings
        let defaultCategory = UserDefaults.standard.string(forKey: "defaultCategory") ?? Category.food.rawValue
        _selectedCategory = State(initialValue: Category(rawValue: defaultCategory) ?? .food)
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
                            CategoryGrid(selectedCategory: $selectedCategory)
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
                            .padding(.vertical, 10)
                    }
                    .padding(.horizontal)
                    .padding(.top, 10)
                    .padding(.bottom, keyboardHeight > 0 ? keyboardHeight - 40 : 20)
                }
                
                // Success animation overlay
                if animateSuccess {
                    successOverlay
                }
            }
            .navigationTitle("Add Expense")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                setupKeyboardObservers()
            }
            .onDisappear {
                removeKeyboardObservers()
            }
            .alert(validationMessage, isPresented: $showingValidationAlert) {
                Button("OK", role: .cancel) { }
            }
        }
    }
    
    // MARK: - Main Data Card
    
    private var mainDataCard: some View {
        CardView(title: "Expense Details", showDivider: true) {
            VStack(spacing: 16) {
                // Title field
                TextFormField(
                    label: "Title",
                    text: $title,
                    placeholder: "Expense title",
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
            TextEditor(text: $notes)
                .font(.body)
                .padding(10)
                .frame(minHeight: 100)
                .background(Color(.tertiarySystemBackground))
                .cornerRadius(10)
                .padding(.horizontal)
                .padding(.bottom, 8)
        }
    }
    
    // MARK: - Save Button
    
    private var saveButton: some View {
        Button(action: saveExpense) {
            HStack {
                Spacer()
                Text("Save Expense")
                    .fontWeight(.bold)
                Spacer()
            }
            .padding()
            .background(isFormValid() ? Color.accentColor : Color.gray)
            .foregroundColor(.white)
            .cornerRadius(16)
        }
        .disabled(!isFormValid())
    }
    
    // MARK: - Success Overlay
    
    private var successOverlay: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.green)
                
                Text("Expense Added!")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
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
        // Validate inputs
        if title.isEmpty {
            showValidationAlert("Please enter a title for your expense.")
            return
        }
        
        if price.isEmpty {
            showValidationAlert("Please enter the expense amount.")
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
        
        // Add the expense with all fields
        viewModel.addExpense(
            title: title,
            price: priceValue,
            category: selectedCategory
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
    
    private func setupKeyboardObservers() {
        NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillShowNotification, object: nil, queue: .main) { notification in
            if let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
                self.keyboardHeight = keyboardFrame.height
            }
        }
        
        NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillHideNotification, object: nil, queue: .main) { _ in
            self.keyboardHeight = 0
        }
    }
    
    private func removeKeyboardObservers() {
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillHideNotification, object: nil)
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
}
