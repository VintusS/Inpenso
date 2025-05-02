//
//  AnalyticsViewModel.swift
//  iExpense
//
//  Created by Dragomir Mindrescu on 27.04.2025.
//

import Foundation
import SwiftUI

// Structure to hold insight about spending
struct SpendingInsight {
    let type: InsightType
    let title: String
    let description: String
    let icon: String
    let color: Color
    
    enum InsightType {
        case positive
        case neutral
        case negative
    }
}

// Structure to hold daily spending data
struct DailySpending {
    let date: Date
    let amount: Double
    let dayOfMonth: Int
    
    var weekday: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date)
    }
}

// Monthly trend data
struct MonthlyTrend {
    let month: Int
    let year: Int
    let amount: Double
    
    var monthName: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM"
        let calendar = Calendar.current
        var components = DateComponents()
        components.month = month
        components.year = year
        guard let date = calendar.date(from: components) else { return "" }
        return dateFormatter.string(from: date)
    }
    
    var shortMonthName: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM"
        let calendar = Calendar.current
        var components = DateComponents()
        components.month = month
        components.year = year
        guard let date = calendar.date(from: components) else { return "" }
        return dateFormatter.string(from: date)
    }
}

// Category spending trend data
struct CategoryTrend {
    let category: Category
    let previousAmount: Double
    let currentAmount: Double
    
    var percentChange: Double {
        guard previousAmount > 0 else { return currentAmount > 0 ? 100 : 0 }
        return ((currentAmount - previousAmount) / previousAmount) * 100
    }
    
    var isIncreasing: Bool {
        return currentAmount > previousAmount
    }
}

@MainActor
class AnalyticsViewModel: ObservableObject {
    @Published private(set) var totalSpent: Double = 0.0
    @Published private(set) var spendingByCategory: [Category: Double] = [:]
    @Published private(set) var dailySpending: [DailySpending] = []
    @Published private(set) var monthlyTrends: [MonthlyTrend] = []
    @Published private(set) var categoryTrends: [CategoryTrend] = []
    @Published private(set) var insights: [SpendingInsight] = []
    @Published private(set) var averageDailySpend: Double = 0.0
    @Published private(set) var projectedMonthlySpend: Double = 0.0
    @Published private(set) var biggestExpenseCategory: (Category, Double)? = nil
    @Published private(set) var fastestGrowingCategory: (Category, Double)? = nil
    
    @Published var selectedMonth: Int = Calendar.current.component(.month, from: Date())
    @Published var selectedYear: Int = Calendar.current.component(.year, from: Date())
    
    @Published var monthlyBudgets: [String: Double] = [:]
    @Published var currentBudget: Double = 0.0
    @Published var budgetRemainingPerDay: Double = 0.0
    @Published var daysRemainingInMonth: Int = 0
    
    private var expenses: [Expense] = []

    init(expenses: [Expense]) {
        self.expenses = expenses
        self.monthlyBudgets = StorageService.loadBudgets()
        calculateAnalytics()
    }
    
    func updateExpenses(_ expenses: [Expense]) {
        self.expenses = expenses
        calculateAnalytics()
    }
    
    func calculateAnalytics() {
        let calendar = Calendar.current
        
        // Filter expenses for the current selected month/year
        let filteredExpenses = expenses.filter { expense in
            let expenseMonth = calendar.component(.month, from: expense.date)
            let expenseYear = calendar.component(.year, from: expense.date)
            return expenseMonth == selectedMonth && expenseYear == selectedYear
        }
        
        // Calculate total spent in the selected month
        totalSpent = filteredExpenses.reduce(0) { $0 + $1.price }
        
        // Calculate spending by category
        var categoryTotals: [Category: Double] = [:]
        for expense in filteredExpenses {
            categoryTotals[expense.category, default: 0] += expense.price
        }
        spendingByCategory = categoryTotals
        
        // Get the biggest expense category
        if let maxCategory = spendingByCategory.max(by: { $0.value < $1.value }) {
            biggestExpenseCategory = maxCategory
        } else {
            biggestExpenseCategory = nil
        }
        
        // Calculate daily spending pattern
        calculateDailySpending(filteredExpenses: filteredExpenses)
        
        // Calculate trends compared to previous months
        calculateMonthlyTrends()
        
        // Calculate category trends
        calculateCategoryTrends()
        
        // Calculate insights
        generateInsights()
        
        // Budget calculations
        let key = budgetKey(forMonth: selectedMonth, year: selectedYear)
        currentBudget = monthlyBudgets[key] ?? 0.0
        
        // Calculate days remaining in month
        calculateDaysRemainingAndBudget()
    }
    
    private func calculateDailySpending(filteredExpenses: [Expense]) {
        let calendar = Calendar.current
        
        // Group expenses by day
        let groupedByDay = Dictionary(grouping: filteredExpenses) { expense in
            calendar.startOfDay(for: expense.date)
        }
        
        // Create daily spending data
        var dailyData: [DailySpending] = []
        
        // Get the start and end of the selected month
        var components = DateComponents()
        components.year = selectedYear
        components.month = selectedMonth
        components.day = 1
        
        guard let startOfMonth = calendar.date(from: components) else { return }
        guard let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: startOfMonth) else { return }
        
        // Create array of all days in the month
        var currentDate = startOfMonth
        while currentDate <= endOfMonth {
            let dayOfMonth = calendar.component(.day, from: currentDate)
            let amount = groupedByDay[calendar.startOfDay(for: currentDate)]?.reduce(0) { $0 + $1.price } ?? 0
            
            dailyData.append(DailySpending(
                date: currentDate,
                amount: amount,
                dayOfMonth: dayOfMonth
            ))
            
            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: currentDate) else { break }
            currentDate = nextDay
        }
        
        dailySpending = dailyData
        
        // Calculate average daily spend for days with expenses
        let daysWithExpenses = dailyData.filter { $0.amount > 0 }
        if !daysWithExpenses.isEmpty {
            averageDailySpend = daysWithExpenses.reduce(0) { $0 + $1.amount } / Double(daysWithExpenses.count)
        } else {
            averageDailySpend = 0
        }
        
        // Calculate projected monthly spend based on daily average
        if averageDailySpend > 0 {
            let totalDaysInMonth = dailyData.count
            projectedMonthlySpend = averageDailySpend * Double(totalDaysInMonth)
        } else {
            projectedMonthlySpend = totalSpent
        }
    }
    
    private func calculateMonthlyTrends() {
        var trends: [MonthlyTrend] = []
        let calendar = Calendar.current
        
        // Calculate 6 months of data (including current)
        for i in 0..<6 {
            guard let date = calendar.date(byAdding: .month, value: -i, to: Date()) else { continue }
            
            let month = calendar.component(.month, from: date)
            let year = calendar.component(.year, from: date)
            
            let monthlyExpenses = expenses.filter { expense in
                let expenseMonth = calendar.component(.month, from: expense.date)
                let expenseYear = calendar.component(.year, from: expense.date)
                return expenseMonth == month && expenseYear == year
            }
            
            let totalAmount = monthlyExpenses.reduce(0) { $0 + $1.price }
            trends.append(MonthlyTrend(month: month, year: year, amount: totalAmount))
        }
        
        // Sort by date (oldest first)
        monthlyTrends = trends.sorted(by: { 
            if $0.year != $1.year {
                return $0.year < $1.year
            }
            return $0.month < $1.month
        })
    }
    
    private func calculateCategoryTrends() {
        var trends: [CategoryTrend] = []
        let calendar = Calendar.current
        
        // Get current month data
        let currentMonthExpenses = expenses.filter { expense in
            let expenseMonth = calendar.component(.month, from: expense.date)
            let expenseYear = calendar.component(.year, from: expense.date)
            return expenseMonth == selectedMonth && expenseYear == selectedYear
        }
        
        // Get previous month
        var previousMonthComponents = DateComponents()
        previousMonthComponents.month = selectedMonth
        previousMonthComponents.year = selectedYear
        
        guard let currentDate = calendar.date(from: previousMonthComponents),
              let previousMonthDate = calendar.date(byAdding: .month, value: -1, to: currentDate) else { return }
        
        let previousMonth = calendar.component(.month, from: previousMonthDate)
        let previousYear = calendar.component(.year, from: previousMonthDate)
        
        // Get previous month data
        let previousMonthExpenses = expenses.filter { expense in
            let expenseMonth = calendar.component(.month, from: expense.date)
            let expenseYear = calendar.component(.year, from: expense.date)
            return expenseMonth == previousMonth && expenseYear == previousYear
        }
        
        // Calculate current month category totals
        var currentCategoryTotals: [Category: Double] = [:]
        for expense in currentMonthExpenses {
            currentCategoryTotals[expense.category, default: 0] += expense.price
        }
        
        // Calculate previous month category totals
        var previousCategoryTotals: [Category: Double] = [:]
        for expense in previousMonthExpenses {
            previousCategoryTotals[expense.category, default: 0] += expense.price
        }
        
        // Create trend data for each category
        for category in Category.allCases {
            let currentAmount = currentCategoryTotals[category] ?? 0
            let previousAmount = previousCategoryTotals[category] ?? 0
            
            // Only add if there was spending in either month
            if currentAmount > 0 || previousAmount > 0 {
                trends.append(CategoryTrend(
                    category: category,
                    previousAmount: previousAmount,
                    currentAmount: currentAmount
                ))
            }
        }
        
        categoryTrends = trends
        
        // Find fastest growing category (if any has previous data)
        let growingCategories = trends.filter { $0.previousAmount > 0 && $0.currentAmount > $0.previousAmount }
        if let fastestGrowing = growingCategories.max(by: { $0.percentChange < $1.percentChange }) {
            fastestGrowingCategory = (fastestGrowing.category, fastestGrowing.percentChange)
        } else {
            fastestGrowingCategory = nil
        }
    }
    
    private func generateInsights() {
        var newInsights: [SpendingInsight] = []
        
        // Budget insight
        if currentBudget > 0 {
            let percentOfBudgetUsed = (totalSpent / currentBudget) * 100
            
            if percentOfBudgetUsed >= 90 {
                newInsights.append(SpendingInsight(
                    type: .negative,
                    title: "Budget Alert",
                    description: "You've used \(Int(percentOfBudgetUsed))% of your monthly budget.",
                    icon: "exclamationmark.triangle",
                    color: .red
                ))
            } else if percentOfBudgetUsed >= 75 {
                newInsights.append(SpendingInsight(
                    type: .neutral,
                    title: "Budget Notice",
                    description: "You've used \(Int(percentOfBudgetUsed))% of your monthly budget.",
                    icon: "bell",
                    color: .orange
                ))
            } else if daysRemainingInMonth < 7 && percentOfBudgetUsed < 60 {
                newInsights.append(SpendingInsight(
                    type: .positive,
                    title: "Under Budget",
                    description: "Great job! You're under budget this month.",
                    icon: "checkmark.circle",
                    color: .green
                ))
            }
        }
        
        // Category trend insights
        if let fastestGrowing = fastestGrowingCategory, fastestGrowing.1 > 30 {
            newInsights.append(SpendingInsight(
                type: .negative,
                title: "Spending Increase",
                description: "\(fastestGrowing.0.displayName) spending increased by \(Int(fastestGrowing.1))% from last month.",
                icon: "arrow.up.right",
                color: .red
            ))
        }
        
        // Reduction in spending
        let reducedCategories = categoryTrends.filter { 
            $0.previousAmount > 0 && 
            $0.currentAmount < $0.previousAmount && 
            abs($0.percentChange) > 20
        }
        
        if let bestReduction = reducedCategories.min(by: { $0.percentChange < $1.percentChange }) {
            newInsights.append(SpendingInsight(
                type: .positive,
                title: "Spending Decrease",
                description: "You reduced \(bestReduction.category.displayName) spending by \(Int(abs(bestReduction.percentChange)))%.",
                icon: "arrow.down.right",
                color: .green
            ))
        }
        
        // Projected spending insight
        if projectedMonthlySpend > currentBudget && currentBudget > 0 {
            let projectedOverage = projectedMonthlySpend - currentBudget
            let formatter = NumberFormatter()
            formatter.numberStyle = .currency
            formatter.currencyCode = SettingsViewModel.getAppCurrency()
            let formattedOverage = formatter.string(from: NSNumber(value: projectedOverage)) ?? String(projectedOverage)
            
            newInsights.append(SpendingInsight(
                type: .negative,
                title: "Projected Overspending",
                description: "At this rate, you might exceed your budget by \(formattedOverage).",
                icon: "chart.line.uptrend.xyaxis",
                color: .red
            ))
        }
        
        insights = newInsights
    }
    
    private func calculateDaysRemainingAndBudget() {
        let calendar = Calendar.current
        
        // Create date components for the current month
        var components = DateComponents()
        components.year = selectedYear
        components.month = selectedMonth
        components.day = 1
        
        // Get today's date
        let today = calendar.startOfDay(for: Date())
        
        // Get start of the selected month
        guard let startOfMonth = calendar.date(from: components) else { return }
        
        // Get end of the selected month
        guard let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: startOfMonth) else { return }
        
        // If we're viewing a past month, days remaining is 0
        if endOfMonth < today {
            daysRemainingInMonth = 0
            budgetRemainingPerDay = 0
            return
        }
        
        // If we're viewing a future month, days remaining is the full month
        if startOfMonth > today {
            daysRemainingInMonth = calendar.component(.day, from: endOfMonth)
            budgetRemainingPerDay = currentBudget / Double(daysRemainingInMonth)
            return
        }
        
        // Calculate days remaining in the current month
        daysRemainingInMonth = calendar.dateComponents([.day], from: today, to: endOfMonth).day ?? 0
        
        // Calculate remaining budget
        let remainingBudget = max(0, currentBudget - totalSpent)
        
        // Calculate budget per day for the remainder of the month
        budgetRemainingPerDay = daysRemainingInMonth > 0 ? remainingBudget / Double(daysRemainingInMonth) : 0
    }
    
    func changeMonthYear(month: Int, year: Int) {
        selectedMonth = month
        selectedYear = year
        calculateAnalytics()
    }
    
    func budgetKey(forMonth month: Int, year: Int) -> String {
        String(format: "%02d-%d", month, year)
    }
}
