//
//  AnalyticsViewModel.swift
//  iExpense
//

import Foundation
import SwiftUI

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

struct CategoryTrend {
    let categoryID: String
    let previousAmount: Double
    let currentAmount: Double

    var percentChange: Double {
        guard previousAmount > 0 else { return currentAmount > 0 ? 100 : 0 }
        return ((currentAmount - previousAmount) / previousAmount) * 100
    }

    var isIncreasing: Bool {
        currentAmount > previousAmount
    }
}

@MainActor
class AnalyticsViewModel: ObservableObject {
    @Published private(set) var totalSpent: Double = 0.0
    @Published private(set) var totalIncome: Double = 0.0
    @Published private(set) var netCashflow: Double = 0.0
    @Published private(set) var spendingByCategory: [String: Double] = [:]
    @Published private(set) var incomeByCategory: [String: Double] = [:]
    @Published private(set) var dailySpending: [DailySpending] = []
    @Published private(set) var monthlyTrends: [MonthlyTrend] = []
    @Published private(set) var categoryTrends: [CategoryTrend] = []
    @Published private(set) var insights: [SpendingInsight] = []
    @Published private(set) var averageDailySpend: Double = 0.0
    @Published private(set) var projectedMonthlySpend: Double = 0.0
    @Published private(set) var biggestExpenseCategory: (String, Double)? = nil
    @Published private(set) var fastestGrowingCategory: (String, Double)? = nil

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

        let filteredTransactions = expenses.filter { expense in
            let expenseMonth = calendar.component(.month, from: expense.date)
            let expenseYear = calendar.component(.year, from: expense.date)
            return expenseMonth == selectedMonth && expenseYear == selectedYear
        }

        let filteredExpenses = filteredTransactions.filter { $0.type == .expense }
        let filteredIncomes = filteredTransactions.filter { $0.type == .income }

        totalSpent = filteredExpenses.reduce(0) { $0 + $1.price }
        totalIncome = filteredIncomes.reduce(0) { $0 + $1.price }
        netCashflow = totalIncome - totalSpent

        spendingByCategory = totalsByCategory(for: filteredExpenses)
        incomeByCategory = totalsByCategory(for: filteredIncomes)
        biggestExpenseCategory = spendingByCategory.max(by: { $0.value < $1.value })

        calculateDailySpending(filteredExpenses: filteredExpenses)
        calculateMonthlyTrends()
        calculateCategoryTrends()

        let key = budgetKey(forMonth: selectedMonth, year: selectedYear)
        currentBudget = monthlyBudgets[key] ?? 0.0
        calculateDaysRemainingAndBudget()
        generateInsights()
    }

    private func totalsByCategory(for transactions: [Expense]) -> [String: Double] {
        var totals: [String: Double] = [:]
        for transaction in transactions {
            totals[transaction.categoryID, default: 0] += transaction.price
        }
        return totals
    }

    private func calculateDailySpending(filteredExpenses: [Expense]) {
        let calendar = Calendar.current

        let groupedByDay = Dictionary(grouping: filteredExpenses) { expense in
            calendar.startOfDay(for: expense.date)
        }

        var dailyData: [DailySpending] = []
        var components = DateComponents()
        components.year = selectedYear
        components.month = selectedMonth
        components.day = 1

        guard let startOfMonth = calendar.date(from: components),
              let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: startOfMonth) else {
            return
        }

        var currentDate = startOfMonth
        while currentDate <= endOfMonth {
            let dayOfMonth = calendar.component(.day, from: currentDate)
            let amount = groupedByDay[calendar.startOfDay(for: currentDate)]?.reduce(0) { $0 + $1.price } ?? 0

            dailyData.append(DailySpending(date: currentDate, amount: amount, dayOfMonth: dayOfMonth))

            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: currentDate) else { break }
            currentDate = nextDay
        }

        dailySpending = dailyData

        let daysWithExpenses = dailyData.filter { $0.amount > 0 }
        if !daysWithExpenses.isEmpty {
            averageDailySpend = daysWithExpenses.reduce(0) { $0 + $1.amount } / Double(daysWithExpenses.count)
        } else {
            averageDailySpend = 0
        }

        if averageDailySpend > 0 {
            projectedMonthlySpend = averageDailySpend * Double(dailyData.count)
        } else {
            projectedMonthlySpend = totalSpent
        }
    }

    private func calculateMonthlyTrends() {
        var trends: [MonthlyTrend] = []
        let calendar = Calendar.current

        for index in 0..<6 {
            guard let date = calendar.date(byAdding: .month, value: -index, to: Date()) else { continue }

            let month = calendar.component(.month, from: date)
            let year = calendar.component(.year, from: date)

            let totalAmount = expenses
                .filter { expense in
                    let expenseMonth = calendar.component(.month, from: expense.date)
                    let expenseYear = calendar.component(.year, from: expense.date)
                    return expense.type == .expense && expenseMonth == month && expenseYear == year
                }
                .reduce(0) { $0 + $1.price }

            trends.append(MonthlyTrend(month: month, year: year, amount: totalAmount))
        }

        monthlyTrends = trends.sorted {
            if $0.year != $1.year {
                return $0.year < $1.year
            }
            return $0.month < $1.month
        }
    }

    private func calculateCategoryTrends() {
        let calendar = Calendar.current

        let currentMonthExpenses = expenses.filter { expense in
            let expenseMonth = calendar.component(.month, from: expense.date)
            let expenseYear = calendar.component(.year, from: expense.date)
            return expense.type == .expense && expenseMonth == selectedMonth && expenseYear == selectedYear
        }

        var previousMonthComponents = DateComponents()
        previousMonthComponents.month = selectedMonth
        previousMonthComponents.year = selectedYear

        guard let currentDate = calendar.date(from: previousMonthComponents),
              let previousMonthDate = calendar.date(byAdding: .month, value: -1, to: currentDate) else {
            categoryTrends = []
            fastestGrowingCategory = nil
            return
        }

        let previousMonth = calendar.component(.month, from: previousMonthDate)
        let previousYear = calendar.component(.year, from: previousMonthDate)

        let previousMonthExpenses = expenses.filter { expense in
            let expenseMonth = calendar.component(.month, from: expense.date)
            let expenseYear = calendar.component(.year, from: expense.date)
            return expense.type == .expense && expenseMonth == previousMonth && expenseYear == previousYear
        }

        let currentCategoryTotals = totalsByCategory(for: currentMonthExpenses)
        let previousCategoryTotals = totalsByCategory(for: previousMonthExpenses)
        let categoryIDs = Set(currentCategoryTotals.keys).union(previousCategoryTotals.keys)

        let trends = categoryIDs.compactMap { categoryID -> CategoryTrend? in
            let currentAmount = currentCategoryTotals[categoryID] ?? 0
            let previousAmount = previousCategoryTotals[categoryID] ?? 0

            guard currentAmount > 0 || previousAmount > 0 else { return nil }
            return CategoryTrend(
                categoryID: categoryID,
                previousAmount: previousAmount,
                currentAmount: currentAmount
            )
        }

        categoryTrends = trends

        let growingCategories = trends.filter { $0.previousAmount > 0 && $0.currentAmount > $0.previousAmount }
        if let fastestGrowing = growingCategories.max(by: { $0.percentChange < $1.percentChange }) {
            fastestGrowingCategory = (fastestGrowing.categoryID, fastestGrowing.percentChange)
        } else {
            fastestGrowingCategory = nil
        }
    }

    private func generateInsights() {
        var newInsights: [SpendingInsight] = []

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

        if let fastestGrowing = fastestGrowingCategory, fastestGrowing.1 > 30 {
            newInsights.append(SpendingInsight(
                type: .negative,
                title: "Spending Increase",
                description: "\(categoryName(for: fastestGrowing.0)) spending increased by \(Int(fastestGrowing.1))% from last month.",
                icon: "arrow.up.right",
                color: .red
            ))
        }

        let reducedCategories = categoryTrends.filter {
            $0.previousAmount > 0 &&
            $0.currentAmount < $0.previousAmount &&
            abs($0.percentChange) > 20
        }

        if let bestReduction = reducedCategories.min(by: { $0.percentChange < $1.percentChange }) {
            newInsights.append(SpendingInsight(
                type: .positive,
                title: "Spending Decrease",
                description: "You reduced \(categoryName(for: bestReduction.categoryID)) spending by \(Int(abs(bestReduction.percentChange)))%.",
                icon: "arrow.down.right",
                color: .green
            ))
        }

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

        var components = DateComponents()
        components.year = selectedYear
        components.month = selectedMonth
        components.day = 1

        let today = calendar.startOfDay(for: Date())

        guard let startOfMonth = calendar.date(from: components),
              let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: startOfMonth) else {
            return
        }

        if endOfMonth < today {
            daysRemainingInMonth = 0
            budgetRemainingPerDay = 0
            return
        }

        if startOfMonth > today {
            daysRemainingInMonth = calendar.component(.day, from: endOfMonth)
            budgetRemainingPerDay = currentBudget / Double(daysRemainingInMonth)
            return
        }

        daysRemainingInMonth = calendar.dateComponents([.day], from: today, to: endOfMonth).day ?? 0

        let remainingBudget = max(0, currentBudget - totalSpent)
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

    private func categoryName(for categoryID: String) -> String {
        if let catalogState = StorageService.loadCategoryCatalogState() {
            let builtInCategories = FinanceCategory.builtInCategories.map { category in
                catalogState.builtInOverrides[category.id] ?? category
            }

            if let category = (builtInCategories + catalogState.customCategories).first(where: { $0.id == categoryID }) {
                return category.displayName
            }
        }

        if let builtInCategory = Category.category(from: categoryID) {
            return builtInCategory.displayName
        }

        return StorageService.loadCustomCategories()
            .first { $0.id == categoryID }?
            .displayName ?? FinanceCategory.fallback.displayName
    }
}
