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
    @State private var price: String = ""
    @State private var selectedCategory: Category = .food

    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("Expense Title", text: $title)
                    
                    TextField("Price", text: $price)
                        .keyboardType(.decimalPad)
                    
                    Picker("Category", selection: $selectedCategory) {
                        ForEach(Category.allCases, id: \.self) { category in
                            Text(category.displayName)
                        }
                    }
                } header: {
                    Text("Expense Details")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Add Expense")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveExpense()
                    }
                    .disabled(title.isEmpty || price.isEmpty)
                }
            }
        }
    }
    
    private func saveExpense() {
        price.replace(",", with: ".")
        guard let priceValue = Double(price) else { return }
        viewModel.addExpense(title: title, price: priceValue, category: selectedCategory)
        dismiss()
    }
}

#Preview {
    AddExpenseView(viewModel: ExpenseViewModel())
}
