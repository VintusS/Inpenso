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
    @StateObject private var analyticsViewModel = AnalyticsViewModel(expenses: [])

    var body: some View {
        NavigationView {
            VStack {
                analyticsSummary

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
                    .onDelete(perform: deleteExpense)
                }
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
                ToolbarItem(placement: .navigationBarLeading) {
                    NavigationLink(destination: AnalyticsView(analyticsViewModel: analyticsViewModel)) {
                        Label("Analytics", systemImage: "chart.pie.fill")
                    }
                }
            }
            .sheet(isPresented: $showingAddExpense) {
                AddExpenseView(viewModel: viewModel)
            }
            .onAppear {
                analyticsViewModel.updateExpenses(viewModel.expenses)
            }
            .onChange(of: viewModel.expenses) { newExpenses in
                analyticsViewModel.updateExpenses(newExpenses)
            }
        }
    }
    
    private func deleteExpense(at offsets: IndexSet) {
        viewModel.deleteExpense(at: offsets)
    }

    private var analyticsSummary: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Total Spent: \(analyticsViewModel.totalSpent, format: .currency(code: "USD"))")
                .font(.title2)
                .bold()

            if !analyticsViewModel.spendingByCategory.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(analyticsViewModel.spendingByCategory.sorted(by: { $0.value > $1.value }), id: \.key) { category, amount in
                        Text("\(category.displayName): \(amount, format: .currency(code: "USD"))")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(.thinMaterial)
        .cornerRadius(12)
        .padding([.horizontal, .top])
    }
}

#Preview {
    let viewModel = ExpenseViewModel()
    viewModel.expenses = [
        Expense(title: "Coffee", amount: 4.5, date: Date(), category: .food),
        Expense(title: "Rent", amount: 1200, date: Date(), category: .rent),
        Expense(title: "Shoes", amount: 75, date: Date(), category: .shopping)
    ]
    
    return HomeView()
}

