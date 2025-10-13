//
//  MonthlyTrendView.swift
//  iExpense
//
//  Created by Dragomir Mindrescu on 27.04.2025.
//

import SwiftUI
import Charts

/// Use the MonthlyTrend data structure from AnalyticsViewModel
extension MonthlyTrend: Identifiable {
    public var id: String { "\(month)-\(year)" }
}

/// A component that displays monthly spending trends
struct MonthlyTrendsView: View {
    let monthlyTrends: [MonthlyTrend]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Monthly Spending")
                .font(.headline)
            
            if monthlyTrends.isEmpty {
                Text("No data available")
                    .foregroundColor(.secondary)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                // Wrap the Chart in a GeometryReader to control its size precisely
                GeometryReader { geometry in
                    Chart {
                        ForEach(monthlyTrends) { trend in
                            LineMark(
                                x: .value("Month", trend.shortMonthName),
                                y: .value("Amount", trend.amount)
                            )
                            .foregroundStyle(Color.blue.gradient)
                            .symbol {
                                Circle()
                                    .fill(Color.blue)
                                    .frame(width: 7, height: 7)
                            }
                            .interpolationMethod(.catmullRom)
                            
                            AreaMark(
                                x: .value("Month", trend.shortMonthName),
                                y: .value("Amount", trend.amount)
                            )
                            .foregroundStyle(
                                .linearGradient(
                                    colors: [.blue.opacity(0.3), .blue.opacity(0.0)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .interpolationMethod(.catmullRom)
                        }
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading)
                    }
                    // Disable chart gestures
                    .allowsHitTesting(false)
                    // Fill the geometry reader
                    .frame(width: geometry.size.width, height: 180)
                }
                .frame(height: 180)
                .fixedSize(horizontal: false, vertical: true)
                
                if let firstTrend = monthlyTrends.first,
                   let lastTrend = monthlyTrends.last,
                   firstTrend.amount > 0, lastTrend.amount > 0 {
                    let percentChange = ((lastTrend.amount - firstTrend.amount) / firstTrend.amount) * 100
                    HStack {
                        Image(systemName: percentChange >= 0 ? "arrow.up.right" : "arrow.down.right")
                            .foregroundColor(percentChange >= 0 ? .red : .green)
                        
                        Text("\(abs(Int(percentChange)))% \(percentChange >= 0 ? "increase" : "decrease") over \(monthlyTrends.count) months")
                            .font(.caption)
                            .foregroundColor(.secondary)
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
        // Prevent gesture interference
        .contentShape(Rectangle())
    }
}

/// A component that displays category trend information
struct CategoryTrendsView: View {
    struct CategoryTrend: Identifiable {
        var id: String { "\(category.rawValue)-\(month)-\(year)" }
        let category: Category
        let month: Int
        let year: Int
        let currentAmount: Double
        let previousAmount: Double
        var percentChange: Double {
            if previousAmount == 0 { return 0 }
            return ((currentAmount - previousAmount) / previousAmount) * 100
        }
        var isIncreasing: Bool {
            return currentAmount > previousAmount
        }
    }
    
    let categoryTrends: [CategoryTrend]
    let currencyCode: String
    
    init(
        categoryTrends: [CategoryTrend],
        currencyCode: String? = nil
    ) {
        self.categoryTrends = categoryTrends
        self.currencyCode = currencyCode ?? SettingsViewModel.getAppCurrency()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Category Changes")
                .font(.headline)
            
            if categoryTrends.isEmpty {
                Text("No data available for comparison")
                    .foregroundColor(.secondary)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                let sortedTrends = categoryTrends
                    .filter { $0.previousAmount > 0 } // Only categories with previous month data
                    .sorted { abs($0.percentChange) > abs($1.percentChange) } // Sort by absolute percent change
                    .prefix(4) // Top 4 changes
                
                VStack(spacing: 10) {
                    ForEach(Array(sortedTrends)) { trend in
                        categoryTrendRow(trend: trend)
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
    }
    
    private func categoryTrendRow(trend: CategoryTrend) -> some View {
        HStack {
            // Category color and name
            Circle()
                .fill(trend.category.color)
                .frame(width: 12, height: 12)
            
            Text(trend.category.displayName)
                .font(.subheadline)
            
            Spacer()
            
            // Trend indicator and percentage
            HStack(spacing: 4) {
                Image(systemName: trend.isIncreasing ? "arrow.up" : "arrow.down")
                    .foregroundColor(trend.isIncreasing ? .red : .green)
                
                Text("\(Int(abs(trend.percentChange)))%")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(trend.isIncreasing ? .red : .green)
            }
            
            // Amounts
            VStack(alignment: .trailing) {
                Text(trend.currentAmount, format: .currency(code: currencyCode))
                    .font(.caption)
                
                Text(trend.previousAmount, format: .currency(code: currencyCode))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }
}

/// A component that displays spending projections
struct ProjectionView: View {
    let projectedMonthlySpend: Double
    let currentBudget: Double
    let currencyCode: String
    
    init(
        projectedMonthlySpend: Double, 
        currentBudget: Double,
        currencyCode: String? = nil
    ) {
        self.projectedMonthlySpend = projectedMonthlySpend
        self.currentBudget = currentBudget
        self.currencyCode = currencyCode ?? SettingsViewModel.getAppCurrency()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Monthly Projection")
                .font(.headline)
            
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Projected")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text(projectedMonthlySpend, format: .currency(code: currencyCode))
                        .font(.title3)
                        .fontWeight(.bold)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                if currentBudget > 0 {
                    Divider()
                        .frame(height: 50)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Budget")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Text(currentBudget, format: .currency(code: currencyCode))
                            .font(.title3)
                            .fontWeight(.bold)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Divider()
                        .frame(height: 50)
                    
                    VStack(alignment: .trailing, spacing: 8) {
                        Text("Difference")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        let difference = projectedMonthlySpend - currentBudget
                        Text(abs(difference), format: .currency(code: currencyCode))
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(difference > 0 ? .red : .green)
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
            
            if currentBudget > 0 {
                let isOverBudget = projectedMonthlySpend > currentBudget
                
                Text(isOverBudget ? "You are projected to exceed your budget" : "You are projected to stay under budget")
                    .font(.subheadline)
                    .foregroundColor(isOverBudget ? .red : .green)
                    .padding(.top, 4)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
    }
}

#Preview {
    VStack(spacing: 20) {
        // Monthly trends preview
        let trendData = (1...6).map { month in
            MonthlyTrend(
                month: month,
                year: 2025,
                amount: Double.random(in: 1500...3000)
            )
        }
        
        MonthlyTrendsView(monthlyTrends: trendData)
            .frame(height: 250)
        
        // Category trends preview
        let categoryTrends = [
            CategoryTrendsView.CategoryTrend(
                category: .food,
                month: 5,
                year: 2025,
                currentAmount: 450.50,
                previousAmount: 380.25
            ),
            CategoryTrendsView.CategoryTrend(
                category: .transportation,
                month: 5,
                year: 2025,
                currentAmount: 220.75,
                previousAmount: 280.50
            ),
            CategoryTrendsView.CategoryTrend(
                category: .entertainment,
                month: 5,
                year: 2025,
                currentAmount: 180.25,
                previousAmount: 120.75
            )
        ]
        
        CategoryTrendsView(categoryTrends: categoryTrends)
        
        // Projection preview
        ProjectionView(
            projectedMonthlySpend: 2850.50,
            currentBudget: 3000.00
        )
    }
    .padding()
} 
