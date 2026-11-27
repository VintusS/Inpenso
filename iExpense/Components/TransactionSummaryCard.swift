//
//  TransactionSummaryCard.swift
//  iExpense
//

import SwiftUI

/// Month totals shown above the transaction list, with budget progress when a budget is set.
struct TransactionSummaryCard: View {
    let income: Double
    let spent: Double
    let net: Double
    let itemCount: Int
    let budget: Double
    let currencyCode: String

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(spacing: 16) {
            let columns = dynamicTypeSize.isAccessibilitySize ? 1 : 2
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), alignment: .topLeading), count: columns),
                spacing: 12
            ) {
                metric(title: "Income", amount: income, color: .green)
                metric(title: "Spent", amount: spent, color: .primary)
                metric(title: "Net", amount: net, color: net >= 0 ? .green : .red)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Items")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text(itemCount, format: .number)
                        .font(.title3.bold())
                }
            }

            if budget > 0 {
                budgetProgress
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
                .shadow(color: Color(.label).opacity(0.05), radius: 5, x: 0, y: 2)
        )
    }

    private func metric(title: String, amount: Double, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)

            Text(amount, format: .currency(code: currencyCode))
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(color)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var budgetProgress: some View {
        VStack(spacing: 6) {
            let layout = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
                : AnyLayout(HStackLayout())
            layout {
                Text("Monthly Budget")
                if !dynamicTypeSize.isAccessibilitySize { Spacer() }
                Text("\(spent.formatted(.currency(code: currencyCode))) of \(budget.formatted(.currency(code: currencyCode)))")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .font(.caption)
            .foregroundStyle(.secondary)

            let progress = min(1.0, spent / budget)
            let progressColor: Color = progress < 0.75 ? .blue : (progress < 0.9 ? .orange : .red)

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(.systemGray5))
                        .frame(height: 6)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(progressColor)
                        .frame(width: geometry.size.width * CGFloat(progress), height: 6)
                }
            }
            .frame(height: 6)
        }
    }
}
