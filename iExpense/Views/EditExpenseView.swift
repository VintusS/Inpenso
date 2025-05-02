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
    let expense: Expense

    init(viewModel: ExpenseViewModel, expense: Expense) {
        self.viewModel = viewModel
        self.expense = expense
        _title = State(initialValue: expense.title)
        _price = State(initialValue: String(format: "%.2f", expense.price))
        _selectedDate = State(initialValue: expense.date)
        _selectedCategory = State(initialValue: expense.category)
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Edit Expense")) {
                    TextField("Title", text: $title)

                    TextField("Price", text: $price)
                        .keyboardType(.decimalPad)
                        
                    DatePicker("Date", selection: $selectedDate, displayedComponents: .date)
                }
                
                Section {
                    Text("Category")
                        .font(.headline)
                        .foregroundColor(.secondary)
                        .listRowSeparator(.hidden)
                    
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 15) {
                        ForEach(Category.allCases, id: \.self) { category in
                            CategoryButton(
                                category: category,
                                isSelected: selectedCategory == category,
                                action: {
                                    selectedCategory = category
                                    triggerHaptic()
                                }
                            )
                        }
                    }
                    .padding(.vertical, 5)
                }

                Section {
                    Button(action: {
                        saveChanges()
                        dismiss()
                    }) {
                        Label("Save Changes", systemImage: "checkmark.circle.fill")
                            .foregroundColor(.blue)
                    }

                    Button(role: .destructive) {
                        deleteExpense()
                        dismiss()
                    } label: {
                        Label("Delete Expense", systemImage: "trash.fill")
                    }
                }
            }
            .navigationTitle("Edit Expense")
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
    
    private func triggerHaptic() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }
}

#Preview {
    EditExpenseView(viewModel: ExpenseViewModel(), expense: Expense(title: "Sample", price: 10, date: Date(), category: .food))
}
