//
//  HomeView.swift
//  iExpense
//
//  Created by Dragomir Mindrescu on 27.04.2025.
//

import SwiftUI

struct HomeView: View {
    @StateObject private var viewModel = ExpenseViewModel()
    @State private var showingAddExpense = false

    var body: some View {
        NavigationView {
            List {
                ForEach(viewModel.expenses) { expense in
                    VStack(alignment: .leading, spacing: 5) {
                        Text(expense.title)
                            .font(.headline)
                        Text("\(expense.amount, format: .currency(code: "USD")) • \(expense.category.displayName)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text(expense.date, style: .date)
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .padding(.vertical, 4)
                }
                .onDelete(perform: viewModel.deleteExpense)
            }
            .navigationTitle("iExpense")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    EditButton()
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingAddExpense.toggle()
                    }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddExpense) {
                AddExpenseView(viewModel: viewModel)
            }
        }
    }
}

#Preview {
    HomeView()
}
