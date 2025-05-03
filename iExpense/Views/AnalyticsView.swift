//
//  AnalyticsView.swift
//  iExpense
//
//  Created by Dragomir Mindrescu on 27.04.2025.
//

import SwiftUI
import Charts

struct AnalyticsView: View {
    @ObservedObject var analyticsViewModel: AnalyticsViewModel
    @State private var selectedTab: AnalyticsTab = .overview
    @State private var showSaveBudgetSuccess: Bool = false
    
    // Create local state for MonthYearPicker to avoid wrapper issues
    @State private var selectedMonth: Int
    @State private var selectedYear: Int
    
    init(analyticsViewModel: AnalyticsViewModel) {
        self.analyticsViewModel = analyticsViewModel
        // Initialize the state variables with the view model values
        _selectedMonth = State(initialValue: analyticsViewModel.selectedMonth)
        _selectedYear = State(initialValue: analyticsViewModel.selectedYear)
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Month Year Picker
                MonthYearPicker(
                    selectedMonth: $selectedMonth,
                    selectedYear: $selectedYear,
                    onMonthYearChanged: {
                        // Update view model values
                        analyticsViewModel.selectedMonth = selectedMonth
                        analyticsViewModel.selectedYear = selectedYear
                        analyticsViewModel.calculateAnalytics()
                    }
                )
                .padding(.horizontal)
                .padding(.bottom, 8)
                
                // Tab Selection
                AnalyticsTabSelector(selectedTab: $selectedTab)
                    .padding(.horizontal)
                
                // Content based on selected tab
                ScrollView(.vertical, showsIndicators: true) {
                    VStack(spacing: 16) {
                        switch selectedTab {
                        case .overview:
                            overviewTabContent
                        case .trends:
                            trendsTabContent
                        case .insights:
                            insightsTabContent
                        case .budget:
                            budgetTabContent
                        }
                    }
                    .padding()
                }
                .scrollDisabled(false)
            }
            .navigationTitle("Analytics")
            .alert("Budget Saved", isPresented: $showSaveBudgetSuccess) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Your monthly budget has been saved successfully.")
            }
        }
    }
    
    // MARK: - Overview Tab Content
    
    private var overviewTabContent: some View {
        VStack(spacing: 20) {
            // Summary Cards
            summaryCardsGrid
            
            // Daily Spending Graph
            DailySpendingChartView(
                dailySpending: analyticsViewModel.dailySpending.map { spending in
                    DailySpendingChartView.DailySpending(
                        date: spending.date,
                        dayOfMonth: spending.dayOfMonth,
                        amount: spending.amount
                    )
                },
                averageDailySpend: analyticsViewModel.averageDailySpend
            )
            .frame(height: 220)
            
            // Category Spending Breakdown
            CategoryBreakdownView(
                spendingByCategory: analyticsViewModel.spendingByCategory,
                totalSpent: analyticsViewModel.totalSpent
            )
        }
    }
    
    private var summaryCardsGrid: some View {
        SummaryCardGrid(summaryCards: [
            // Total Spent
            SummaryCard(
                title: "Total Spent",
                value: analyticsViewModel.totalSpent,
                valueFormat: .currency,
                icon: "dollarsign.circle.fill",
                color: .blue
            ),

            // Daily Average
            SummaryCard(
                title: "Daily Average",
                value: analyticsViewModel.averageDailySpend,
                valueFormat: .currency,
                icon: "calendar.badge.clock",
                color: .green
            ),

            // Budget Used or No Budget
            analyticsViewModel.currentBudget > 0 ?
                SummaryCard(
                    title: "Budget Used",
                    value: min(100, (analyticsViewModel.totalSpent / analyticsViewModel.currentBudget) * 100),
                    valueFormat: .percent,
                    icon: "chart.pie.fill",
                    color: min(100, (analyticsViewModel.totalSpent / analyticsViewModel.currentBudget) * 100) >= 90 ? .red : 
                          (min(100, (analyticsViewModel.totalSpent / analyticsViewModel.currentBudget) * 100) >= 75 ? .orange : .blue)
                ) :
                SummaryCard(
                    title: "Budget",
                    value: 0,
                    valueFormat: .noBudget,
                    icon: "chart.pie.fill",
                    color: .gray
                ),

            // Remaining Per Day or Days Left
            analyticsViewModel.currentBudget > 0 && analyticsViewModel.daysRemainingInMonth > 0 ?
                SummaryCard(
                    title: "Per Day Left",
                    value: analyticsViewModel.budgetRemainingPerDay,
                    valueFormat: .currency,
                    icon: "calendar.badge.clock",
                    color: .purple
                ) :
                SummaryCard(
                    title: "Days Left",
                    value: Double(analyticsViewModel.daysRemainingInMonth),
                    valueFormat: .days,
                    icon: "calendar",
                    color: .purple
                )
        ])
    }
    
    // MARK: - Trends Tab Content
    
    private var trendsTabContent: some View {
        VStack(spacing: 20) {
            // Monthly Trends Graph
            MonthlyTrendsView(monthlyTrends: analyticsViewModel.monthlyTrends)
                .frame(height: 250)
                .fixedSize(horizontal: false, vertical: true)
            
            // Top Growing Categories
            CategoryTrendsView(categoryTrends: analyticsViewModel.categoryTrends.map { trend in
                CategoryTrendsView.CategoryTrend(
                    category: trend.category,
                    month: analyticsViewModel.selectedMonth,
                    year: analyticsViewModel.selectedYear,
                    currentAmount: trend.currentAmount,
                    previousAmount: trend.previousAmount
                )
            })
            
            // Monthly Projection
            if analyticsViewModel.projectedMonthlySpend > 0 {
                ProjectionView(
                    projectedMonthlySpend: analyticsViewModel.projectedMonthlySpend,
                    currentBudget: analyticsViewModel.currentBudget
                )
            }
        }
    }
    
    // MARK: - Insights Tab Content
    
    private var insightsTabContent: some View {
        VStack(spacing: 20) {
            // Key stats at the top
            KeyStatisticsView(
                biggestExpenseCategory: analyticsViewModel.biggestExpenseCategory,
                totalSpent: analyticsViewModel.totalSpent,
                mostActiveSpendingPeriod: findMostActiveSpendingPeriod()
            )
            
            // Auto-generated insights
            InsightsCardView(insights: analyticsViewModel.insights)
            
            // Spending Pattern Analysis
            SpendingPatternView(
                weekdayVsWeekendAnalysis: analyzeWeekdayVsWeekend(),
                monthlyPatternAnalysis: analyzeMonthlyPattern()
            )
        }
    }
    
    private func findMostActiveSpendingPeriod() -> String? {
        let dailySpending = analyticsViewModel.dailySpending
        
        // Only include days with expenses
        let daysWithExpenses = dailySpending.filter { $0.amount > 0 }
        
        if daysWithExpenses.isEmpty {
            return nil
        }
        
        // Group by weekday and find the weekday with highest average spending
        let weekdayGroups = Dictionary(grouping: daysWithExpenses) { day in
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "EEEE" // Full weekday name
            return dateFormatter.string(from: day.date)
        }
        
        let weekdayAverages = weekdayGroups.mapValues { days in
            days.reduce(0) { $0 + $1.amount } / Double(days.count)
        }
        
        if let topWeekday = weekdayAverages.max(by: { $0.value < $1.value }) {
            return topWeekday.key
        }
        
        return nil
    }
    
    private func analyzeWeekdayVsWeekend() -> SpendingPatternView.PatternAnalysis? {
        let dailySpending = analyticsViewModel.dailySpending
        
        // Only analyze if we have spending data
        if dailySpending.isEmpty {
            return nil
        }
        
        // Group by weekday type
        var weekdaySpending: [Double] = []
        var weekendSpending: [Double] = []
        
        for day in dailySpending {
            let calendar = Calendar.current
            let weekday = calendar.component(.weekday, from: day.date)
            
            // In most calendars Sunday is 1 and Saturday is 7
            if weekday == 1 || weekday == 7 {
                weekendSpending.append(day.amount)
            } else {
                weekdaySpending.append(day.amount)
            }
        }
        
        let weekdayAvg = weekdaySpending.reduce(0, +) / Double(max(1, weekdaySpending.count))
        let weekendAvg = weekendSpending.reduce(0, +) / Double(max(1, weekendSpending.count))
        
        // Calculate the ratio
        let ratio = weekdayAvg > 0 ? weekendAvg / weekdayAvg : 0
        
        if ratio > 1.5 {
            return SpendingPatternView.PatternAnalysis(
                title: "Weekend Spender",
                description: "You spend \(Int(ratio * 100))% more on weekends compared to weekdays",
                icon: "party.popper",
                color: .orange
            )
        } else if ratio > 1.1 {
            return SpendingPatternView.PatternAnalysis(
                title: "Slightly Higher Weekend Spending",
                description: "Your weekend spending is moderately higher than weekdays",
                icon: "calendar.badge.plus",
                color: .blue
            )
        } else if ratio < 0.7 {
            return SpendingPatternView.PatternAnalysis(
                title: "Weekday Focused",
                description: "You spend significantly more on weekdays than weekends",
                icon: "briefcase",
                color: .purple
            )
        } else {
            return SpendingPatternView.PatternAnalysis(
                title: "Balanced Spending",
                description: "Your spending is fairly consistent throughout the week",
                icon: "equal.circle",
                color: .green
            )
        }
    }
    
    private func analyzeMonthlyPattern() -> SpendingPatternView.PatternAnalysis? {
        let dailySpending = analyticsViewModel.dailySpending
        
        // Only analyze if we have spending data
        if dailySpending.isEmpty {
            return nil
        }
        
        // Split the month into early (1-10), mid (11-20), and late (21+)
        var earlyMonthSpending: [Double] = []
        var midMonthSpending: [Double] = []
        var lateMonthSpending: [Double] = []
        
        for day in dailySpending {
            if day.dayOfMonth <= 10 {
                earlyMonthSpending.append(day.amount)
            } else if day.dayOfMonth <= 20 {
                midMonthSpending.append(day.amount)
            } else {
                lateMonthSpending.append(day.amount)
            }
        }
        
        let earlyAvg = earlyMonthSpending.reduce(0, +) / Double(max(1, earlyMonthSpending.count))
        let midAvg = midMonthSpending.reduce(0, +) / Double(max(1, midMonthSpending.count))
        let lateAvg = lateMonthSpending.reduce(0, +) / Double(max(1, lateMonthSpending.count))
        
        let maxAvg = max(earlyAvg, max(midAvg, lateAvg))
        
        if maxAvg == earlyAvg && earlyAvg > midAvg * 1.3 && earlyAvg > lateAvg * 1.3 {
            return SpendingPatternView.PatternAnalysis(
                title: "Early Month Spender",
                description: "You tend to spend more in the first part of the month",
                icon: "calendar.badge.plus",
                color: .green
            )
        } else if maxAvg == lateAvg && lateAvg > earlyAvg * 1.3 && lateAvg > midAvg * 1.3 {
            return SpendingPatternView.PatternAnalysis(
                title: "End of Month Spender",
                description: "Your spending increases toward the end of the month",
                icon: "calendar.badge.exclamationmark",
                color: .red
            )
        } else if maxAvg == midAvg && midAvg > earlyAvg * 1.3 && midAvg > lateAvg * 1.3 {
            return SpendingPatternView.PatternAnalysis(
                title: "Mid-Month Spike",
                description: "Your spending peaks in the middle of the month",
                icon: "waveform.path.ecg",
                color: .orange
            )
        } else {
            return SpendingPatternView.PatternAnalysis(
                title: "Consistent Throughout Month",
                description: "Your spending is fairly evenly distributed throughout the month",
                icon: "equal.circle",
                color: .blue
            )
        }
    }
    
    // MARK: - Budget Tab Content
    
    private var budgetTabContent: some View {
        VStack(spacing: 20) {
            // Budget Input
            BudgetInputView(
                currentBudget: $analyticsViewModel.currentBudget,
                onSave: saveBudget
            )
            
            // Budget Status
            if analyticsViewModel.currentBudget > 0 {
                BudgetStatusView(
                    totalSpent: analyticsViewModel.totalSpent,
                    currentBudget: analyticsViewModel.currentBudget,
                    daysRemainingInMonth: analyticsViewModel.daysRemainingInMonth,
                    budgetRemainingPerDay: analyticsViewModel.budgetRemainingPerDay
                )
                
                // Budget recommendations
                BudgetRecommendationsView(
                    biggestExpenseCategory: analyticsViewModel.biggestExpenseCategory,
                    totalSpent: analyticsViewModel.totalSpent,
                    currentBudget: analyticsViewModel.currentBudget,
                    daysRemainingInMonth: analyticsViewModel.daysRemainingInMonth,
                    suggestedBudget: calculateSuggestedBudget()
                )
            }
            
            // Historical budget compliance
            BudgetHistoryView(complianceData: createBudgetComplianceData())
        }
    }
    
    private func calculateSuggestedBudget() -> Double {
        // If we have spending history for multiple months, average it with a slight increase
        if analyticsViewModel.monthlyTrends.count >= 3 {
            let recentMonths = Array(analyticsViewModel.monthlyTrends.suffix(3))
            let avgSpending = recentMonths.reduce(0) { $0 + $1.amount } / Double(recentMonths.count)
            return ceil(avgSpending * 1.1 / 10) * 10 // Round up to nearest 10
        }
        
        // If we have the current month's projected spending
        if analyticsViewModel.projectedMonthlySpend > 0 {
            return ceil(analyticsViewModel.projectedMonthlySpend * 1.05 / 10) * 10 // Round up to nearest 10
        }
        
        return 0
    }
    
    private func createBudgetComplianceData() -> [BudgetHistoryView.BudgetComplianceData] {
        var result: [BudgetHistoryView.BudgetComplianceData] = []
        
        // Skip the current month and use previous months
        for trend in analyticsViewModel.monthlyTrends.dropLast() {
            let key = analyticsViewModel.budgetKey(forMonth: trend.month, year: trend.year)
            if let budget = analyticsViewModel.monthlyBudgets[key], budget > 0 {
                let compliancePercent = (trend.amount / budget) * 100
                let color: Color = compliancePercent <= 90 ? .green : 
                                    (compliancePercent <= 100 ? .blue : 
                                    (compliancePercent <= 110 ? .orange : .red))
                
                result.append(BudgetHistoryView.BudgetComplianceData(
                    month: trend.month,
                    year: trend.year,
                    monthName: trend.shortMonthName,
                    compliancePercent: compliancePercent,
                    color: color
                ))
            }
        }
        
        return result
    }
    
    // MARK: - Helper Methods
    
    private func saveBudget() {
        let key = analyticsViewModel.budgetKey(forMonth: analyticsViewModel.selectedMonth, year: analyticsViewModel.selectedYear)
        analyticsViewModel.monthlyBudgets[key] = analyticsViewModel.currentBudget
        StorageService.saveBudgets(analyticsViewModel.monthlyBudgets)
        showSaveBudgetSuccess = true
        HapticFeedback.success()
    }
}

#Preview {
    AnalyticsView(analyticsViewModel: AnalyticsViewModel(expenses: []))
}
