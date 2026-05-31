//
//  CategoryBreakdownView.swift
//  iExpense
//
//  Created by Dragomir Mindrescu on 27.04.2025.
//

import SwiftUI
import Charts

/// A component that displays spending breakdown by category
struct CategoryBreakdownView: View {
    @EnvironmentObject private var categoryStore: CategoryStore

    let spendingByCategory: [String: Double]
    let totalSpent: Double
    let currencyCode: String
    
    init(
        spendingByCategory: [String: Double],
        totalSpent: Double,
        currencyCode: String? = nil
    ) {
        self.spendingByCategory = spendingByCategory
        self.totalSpent = totalSpent
        self.currencyCode = currencyCode ?? SettingsViewModel.getAppCurrency()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Spending by Category")
                .font(.headline)
            
            if spendingByCategory.isEmpty {
                Text("No data available")
                    .foregroundColor(.secondary)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                VStack {
                    // Pie chart
                    Chart {
                        ForEach(spendingByCategory.sorted(by: { $0.value > $1.value }), id: \.key) { categoryID, amount in
                            let category = categoryStore.category(for: categoryID)
                            SectorMark(
                                angle: .value("Amount", amount),
                                innerRadius: .ratio(0.6),
                                angularInset: 1.5
                            )
                            .foregroundStyle(category.color)
                            .cornerRadius(5)
                        }
                    }
                    .frame(height: 200)
                    
                    // Category legend
                    VStack(spacing: 8) {
                        ForEach(spendingByCategory.sorted(by: { $0.value > $1.value }), id: \.key) { categoryID, amount in
                            categoryRow(category: categoryStore.category(for: categoryID), amount: amount)
                        }
                    }
                    .padding(.top, 8)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
    }
    
    private func categoryRow(category: FinanceCategory, amount: Double) -> some View {
        HStack {
            // Color indicator
            Circle()
                .fill(category.color)
                .frame(width: 12, height: 12)
            
            // Category name
            Text(category.displayName)
                .font(.subheadline)
            
            Spacer()
            
            // Category amount and percentage
            if totalSpent > 0 {
                VStack(alignment: .trailing) {
                    Text(amount, format: .currency(code: currencyCode))
                        .font(.subheadline)
                    
                    Text("\(Int((amount / totalSpent) * 100))%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else {
                Text(amount, format: .currency(code: currencyCode))
                    .font(.subheadline)
            }
        }
    }
}

#Preview {
    let sampleData: [String: Double] = [
        Category.food.categoryID: 450.50,
        Category.transportation.categoryID: 220.75,
        Category.rent.categoryID: 1200.00,
        Category.entertainment.categoryID: 180.25,
        Category.utilities.categoryID: 310.80
    ]
    
    CategoryBreakdownView(
        spendingByCategory: sampleData,
        totalSpent: sampleData.values.reduce(0, +)
    )
    .environmentObject(CategoryStore())
    .padding()
} 
