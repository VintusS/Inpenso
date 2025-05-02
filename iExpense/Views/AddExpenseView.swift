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
                } header: {
                    Text("Expense Details")
                        .font(.headline)
                        .foregroundColor(.secondary)
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
    
    private func triggerHaptic() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }
}

struct CategoryButton: View {
    let category: Category
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack {
                Circle()
                    .fill(category.color)
                    .frame(width: 40, height: 40)
                    .overlay(
                        Image(systemName: categoryIcon(for: category))
                            .foregroundColor(.white)
                    )
                    .overlay(
                        Circle()
                            .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 3)
                    )
                
                Text(category.displayName)
                    .font(.caption)
                    .foregroundColor(.primary)
                    .fontWeight(isSelected ? .bold : .regular)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func categoryIcon(for category: Category) -> String {
        switch category {
        case .food:
            return "cart.fill"
        case .eatingOut:
            return "fork.knife"
        case .rent:
            return "house.fill"
        case .shopping:
            return "bag.fill"
        case .entertainment:
            return "tv.fill"
        case .transportation:
            return "car.fill"
        case .utilities:
            return "bolt.fill"
        case .subscriptions:
            return "repeat"
        case .healthcare:
            return "heart.fill"
        case .education:
            return "book.fill"
        case .others:
            return "ellipsis"
        }
    }
}

#Preview {
    AddExpenseView(viewModel: ExpenseViewModel())
}
