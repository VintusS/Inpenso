//
//  EditExpenseView.swift
//  iExpense
//
//  Created by Dragomir Mindrescu on 27.04.2025.
//

import SwiftUI

struct EditExpenseView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var viewModel: ExpenseViewModel

    @State private var title: String
    @State private var price: String
    @State private var selectedDate: Date
    @State private var selectedCategory: Category
    @State private var showDatePicker: Bool = false
    let expense: Expense

    init(viewModel: ExpenseViewModel, expense: Expense) {
        self.viewModel = viewModel
        self.expense = expense
        _title = State(initialValue: expense.title)
        _price = State(initialValue: String(format: "%.2f", expense.price))
        _selectedDate = State(initialValue: expense.date)
        _selectedCategory = State(initialValue: expense.category)
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
                        
                        // Action buttons
                        VStack(spacing: 12) {
                            Button(action: {
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
                }
            }
            .navigationTitle("Edit Expense")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func saveChanges() {
        guard let priceValue = Double(price.replacingOccurrences(of: ",", with: ".")) else { return }
        
        if let index = viewModel.expenses.firstIndex(where: { $0.id == expense.id }) {
            viewModel.expenses[index].title = title
            viewModel.expenses[index].price = priceValue
            viewModel.expenses[index].date = selectedDate
            viewModel.expenses[index].category = selectedCategory
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
}
