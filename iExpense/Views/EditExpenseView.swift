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
    @ObservedObject var viewModel: ExpenseViewModel

    @State private var title: String
    @State private var price: String
    @State private var selectedDate: Date
    @State private var selectedCategory: Category
    @State private var showDatePicker: Bool = false
    @State private var notes: String = ""
    @State private var keyboardHeight: CGFloat = 0
    @State private var keyboardVisible: Bool = false
    let expense: Expense

    init(viewModel: ExpenseViewModel, expense: Expense) {
        print("DEBUG: EditExpenseView init for expense ID \(expense.id.uuidString)")
        self.viewModel = viewModel
        self.expense = expense
        _title = State(initialValue: expense.title)
        _price = State(initialValue: String(format: "%.2f", expense.price))
        _selectedDate = State(initialValue: expense.date)
        _selectedCategory = State(initialValue: expense.category)
        
        // Load notes directly from UserDefaults using expense ID as key
        let notesKey = "notes_\(expense.id.uuidString)"
        // List all the keys in UserDefaults to debug
        print("DEBUG: ALL USERDEFAULTS KEYS:")
        for key in UserDefaults.standard.dictionaryRepresentation().keys {
            if key.starts(with: "notes_") {
                let value = UserDefaults.standard.string(forKey: key) ?? "nil"
                print("DEBUG:   - \(key) = \"\(value)\"")
            }
        }
        
        if let savedNotes = UserDefaults.standard.string(forKey: notesKey) {
            print("DEBUG: Init - Found notes for key \(notesKey): \"\(savedNotes)\"")
            _notes = State(initialValue: savedNotes)
        } else {
            print("DEBUG: Init - No notes found for key \(notesKey)")
            _notes = State(initialValue: "")
        }
    }

    // Current currency symbol
    private var currencySymbol: String {
        let locale = Locale.current
        let currencyCode = SettingsViewModel.getAppCurrency()
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
                        CardView(title: "Expense Details", showDivider: true) {
                            VStack(spacing: 16) {
                                TextFormField(
                                    label: "Title",
                                    text: $title,
                                    placeholder: "Expense title"
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
                            CategoryGrid(selectedCategory: $selectedCategory)
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
                                
                                // Display notes length for debugging
                                Text("Notes length: \(notes.count)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .padding(4)
                                    .background(Color(.systemBackground).opacity(0.7))
                                    .cornerRadius(4)
                                    .padding(8)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
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
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                    Text("Save Changes")
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.accentColor)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                            }
                            
                            Button(action: {
                                hideKeyboard()
                                deleteExpense()
                                HapticFeedback.impact(style: .medium)
                                dismiss()
                            }) {
                                HStack {
                                    Image(systemName: "trash.fill")
                                    Text("Delete Expense")
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.red.opacity(0.8))
                                .foregroundColor(.white)
                                .cornerRadius(12)
                            }
                        }
                        .padding(.top, 10)
                    }
                    .padding()
                    .padding(.bottom, keyboardHeight > 0 ? keyboardHeight - 40 : 20)
                }
            }
            .navigationTitle("Edit Expense")
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
                setupKeyboardObservers()
                print("DEBUG: EditExpenseView appeared with notes: \"\(notes)\"")
                
                // Double check notes loading on appear
                let notesKey = "notes_\(expense.id.uuidString)"
                if let savedNotes = UserDefaults.standard.string(forKey: notesKey) {
                    print("DEBUG: onAppear - Found notes for key \(notesKey): \"\(savedNotes)\"")
                    // Force update notes if there's a mismatch
                    if notes != savedNotes {
                        notes = savedNotes
                        print("DEBUG: onAppear - Updated notes to \"\(notes)\"")
                    }
                } else {
                    print("DEBUG: onAppear - No notes found for key \(notesKey)")
                }
            }
            .onDisappear {
                removeKeyboardObservers()
            }
        }
    }

    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    private func saveChanges() {
        print("DEBUG: Saving changes for expense ID \(expense.id.uuidString)")
        guard let priceValue = Double(price.replacingOccurrences(of: ",", with: ".")) else { return }
        
        if let index = viewModel.expenses.firstIndex(where: { $0.id == expense.id }) {
            viewModel.expenses[index].title = title
            viewModel.expenses[index].price = priceValue
            viewModel.expenses[index].date = selectedDate
            viewModel.expenses[index].category = selectedCategory
            viewModel.saveExpenses()
            
            // Save notes to UserDefaults with expense ID as key
            let notesKey = "notes_\(expense.id.uuidString)"
            UserDefaults.standard.set(notes, forKey: notesKey)
            UserDefaults.standard.synchronize()
            print("DEBUG: Saved notes for key \(notesKey): \"\(notes)\"")
        }
    }

    private func deleteExpense() {
        print("DEBUG: Deleting expense ID \(expense.id.uuidString)")
        if let index = viewModel.expenses.firstIndex(where: { $0.id == expense.id }) {
            viewModel.expenses.remove(at: index)
            viewModel.saveExpenses()
            
            // Remove notes from UserDefaults when expense is deleted
            let notesKey = "notes_\(expense.id.uuidString)"
            UserDefaults.standard.removeObject(forKey: notesKey)
            UserDefaults.standard.synchronize()
            print("DEBUG: Removed notes for key \(notesKey)")
        }
    }
    
    // MARK: - Keyboard Handling
    
    private func setupKeyboardObservers() {
        NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillShowNotification, object: nil, queue: .main) { notification in
            if let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
                self.keyboardHeight = keyboardFrame.height
                withAnimation {
                    self.keyboardVisible = true
                }
            }
        }
        
        NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillHideNotification, object: nil, queue: .main) { _ in
            self.keyboardHeight = 0
            withAnimation {
                self.keyboardVisible = false
            }
        }
    }
    
    private func removeKeyboardObservers() {
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillHideNotification, object: nil)
    }
}

#Preview {
    EditExpenseView(viewModel: ExpenseViewModel(), expense: Expense(title: "Sample", price: 10, date: Date(), category: .food))
}
