import SwiftUI
import Charts

/// A component that displays spending breakdown by category
struct CategoryBreakdownView: View {
    let spendingByCategory: [Category: Double]
    let totalSpent: Double
    let currencyCode: String
    
    init(
        spendingByCategory: [Category: Double],
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
                        ForEach(spendingByCategory.sorted(by: { $0.value > $1.value }), id: \.key) { category, amount in
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
                        ForEach(spendingByCategory.sorted(by: { $0.value > $1.value }), id: \.key) { category, amount in
                            categoryRow(category: category, amount: amount)
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
    
    private func categoryRow(category: Category, amount: Double) -> some View {
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
    let sampleData: [Category: Double] = [
        .food: 450.50,
        .transportation: 220.75,
        .rent: 1200.00,
        .entertainment: 180.25,
        .utilities: 310.80
    ]
    
    CategoryBreakdownView(
        spendingByCategory: sampleData,
        totalSpent: sampleData.values.reduce(0, +)
    )
    .padding()
} 