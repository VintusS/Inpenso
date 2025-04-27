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
    
    @State private var title: String = ""
    @State private var amount: String = ""
    @State private var selectedCategory: Category = .food

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Expense Details")) {
                    TextField("Title", text: $title)
                    
                    TextField("Amount", text: $amount)
                        .keyboardType(.decimalPad)
                    
                    Picker("Category", selection: $selectedCategory) {
                        ForEach(Category.allCases, id: \.self) { category in
                            Text(category.displayName).tag(category)
                        }
                    }
                }
            }
            .navigationTitle("Add Expense")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveExpense()
                    }
                    .disabled(title.isEmpty || amount.isEmpty)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func saveExpense() {
        guard let amountValue = Double(amount) else { return }
        viewModel.addExpense(title: title, amount: amountValue, category: selectedCategory)
        dismiss()
    }
}

#Preview {
    AddExpenseView(viewModel: ExpenseViewModel())
}
