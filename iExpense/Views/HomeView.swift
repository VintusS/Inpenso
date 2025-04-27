//
//  HomeView.swift
//  iExpense
//
//  Created by Dragomir Mindrescu on 27.04.2025.
//

import SwiftUI

struct HomeView: View {
    @ObservedObject var viewModel: ExpenseViewModel
    @ObservedObject var analyticsViewModel: AnalyticsViewModel
    @State private var showingAddExpense = false

    var body: some View {
        NavigationView {
            VStack {
                Spacer()

                totalSpentBox

                Spacer()
            }
            .navigationTitle("Overview")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingAddExpense = true
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

    private var totalSpentBox: some View {
        VStack(spacing: 12) {
            Text("Total Spent")
                .font(.title)
                .fontWeight(.bold)

            Text(analyticsViewModel.totalSpent, format: .currency(code: currentCurrencyCode()))
                .font(.largeTitle)
                .fontWeight(.semibold)
                .foregroundColor(.blue)

            if !analyticsViewModel.spendingByCategory.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(analyticsViewModel.spendingByCategory.sorted(by: { $0.value > $1.value }), id: \.key) { category, price in
                        HStack {
                            Text(category.displayName)
                                .font(.subheadline)
                            Spacer()
                            Text(price, format: .currency(code: currentCurrencyCode()))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.top, 12)
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemBackground)))
        .padding(.horizontal, 32)
    }
}
