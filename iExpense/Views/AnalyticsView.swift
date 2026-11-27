//
//  AnalyticsView.swift
//  iExpense
//
//  Created by Dragomir Mindrescu on 27.04.2025.
//

import SwiftUI
import Charts

struct AnalyticsView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject private var settingsViewModel: SettingsViewModel

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

    private var currencyCode: String {
        settingsViewModel.selectedCurrency
    }
    
    var body: some View {
        NavigationStack {
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

            if analyticsViewModel.currentBudget <= 0 {
                Button {
                    withAnimation(reduceMotion ? nil : .default) { selectedTab = .budget }
                } label: {
                    Label("Set a Monthly Budget", systemImage: "target")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.bordered)
            }
            
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
                totalSpent: analyticsViewModel.totalSpent,
                currencyCode: currencyCode
            )
        }
    }
    
    private var summaryCardsGrid: some View {
        let budget = analyticsViewModel.currentBudget
        let spent = analyticsViewModel.totalSpent
        let percentUsed = budget > 0 ? (spent / budget) * 100 : 0
        let overBudget = budget > 0 && spent > budget
        let dailyBudgetCard = SummaryCard(
            title: "Per Day Left",
            value: analyticsViewModel.budgetRemainingPerDay,
            valueFormat: .currency,
            icon: "calendar.badge.clock",
            color: .purple,
            currencyCode: currencyCode
        )

        return SummaryCardGrid(summaryCards: [
            // Total Spent
            SummaryCard(
                title: "Total Spent",
                value: analyticsViewModel.totalSpent,
                valueFormat: .currency,
                icon: "dollarsign.circle.fill",
                color: .blue,
                currencyCode: currencyCode
            ),

            SummaryCard(
                title: "Income",
                value: analyticsViewModel.totalIncome,
                valueFormat: .currency,
                icon: "arrow.down.circle.fill",
                color: .green,
                currencyCode: currencyCode
            ),

            SummaryCard(
                title: "Net",
                value: analyticsViewModel.netCashflow,
                valueFormat: .currency,
                icon: "equal.circle.fill",
                color: analyticsViewModel.netCashflow >= 0 ? .green : .red,
                currencyCode: currencyCode
            ),

            // Daily Average
            SummaryCard(
                title: "Daily Average",
                value: analyticsViewModel.averageDailySpend,
                valueFormat: .currency,
                icon: "calendar.badge.clock",
                color: .green,
                currencyCode: currencyCode
            ),

            // Budget Used or No Budget
            analyticsViewModel.currentBudget > 0 ?
                SummaryCard(
                    title: "Budget Used",
                    value: percentUsed,
                    valueFormat: .percent,
                    icon: "chart.pie.fill",
                    color: percentUsed >= 90 ? .red :
                          (percentUsed >= 75 ? .orange : .blue),
                    currencyCode: currencyCode
                ) :
                SummaryCard(
                    title: "Budget",
                    value: 0,
                    valueFormat: .noBudget,
                    icon: "chart.pie.fill",
                    color: .gray,
                    currencyCode: currencyCode
                ),

            overBudget ? SummaryCard(
                title: "Over Budget",
                value: spent - budget,
                valueFormat: .currency,
                icon: "exclamationmark.circle.fill",
                color: .red,
                currencyCode: currencyCode
            ) : budget > 0 && analyticsViewModel.daysRemainingInMonth > 0 ? dailyBudgetCard :
                SummaryCard(
                    title: "Days Left",
                    value: Double(analyticsViewModel.daysRemainingInMonth),
                    valueFormat: .days,
                    icon: "calendar",
                    color: .purple,
                    currencyCode: currencyCode
                ),
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
                    categoryID: trend.categoryID,
                    month: analyticsViewModel.selectedMonth,
                    year: analyticsViewModel.selectedYear,
                    currentAmount: trend.currentAmount,
                    previousAmount: trend.previousAmount
                )
            }, currencyCode: currencyCode)
            
            // Monthly Projection
            if analyticsViewModel.projectedMonthlySpend > 0 {
                ProjectionView(
                    projectedMonthlySpend: analyticsViewModel.projectedMonthlySpend,
                    currentBudget: analyticsViewModel.currentBudget,
                    currencyCode: currencyCode
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
                mostActiveSpendingPeriod: findMostActiveSpendingPeriod(),
                currencyCode: currencyCode
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
    
    // MARK: - Budget Tab Content
    
    private var budgetTabContent: some View {
        VStack(spacing: 20) {
            // Budget Input
            BudgetInputView(
                currentBudget: $analyticsViewModel.currentBudget,
                currencyCode: currencyCode,
                onSave: saveBudget
            )
            
            // Budget Status
            if analyticsViewModel.currentBudget > 0 {
                BudgetStatusView(
                    totalSpent: analyticsViewModel.totalSpent,
                    currentBudget: analyticsViewModel.currentBudget,
                    daysRemainingInMonth: analyticsViewModel.daysRemainingInMonth,
                    budgetRemainingPerDay: analyticsViewModel.budgetRemainingPerDay,
                    currencyCode: currencyCode
                )
                
                // Budget recommendations
                BudgetRecommendationsView(
                    biggestExpenseCategory: analyticsViewModel.biggestExpenseCategory,
                    totalSpent: analyticsViewModel.totalSpent,
                    currentBudget: analyticsViewModel.currentBudget,
                    daysRemainingInMonth: analyticsViewModel.daysRemainingInMonth,
                    suggestedBudget: calculateSuggestedBudget(),
                    currencyCode: currencyCode
                )
            }
            
            CategoryBudgetsView(
                limits: analyticsViewModel.categoryBudgets,
                spendingByCategory: analyticsViewModel.spendingByCategory,
                currencyCode: currencyCode,
                onSave: analyticsViewModel.saveCategoryBudgets
            )

            // Historical budget compliance
            BudgetHistoryView(complianceData: createBudgetComplianceData())
        }
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
        .environmentObject(SettingsViewModel())
        .environmentObject(CategoryStore())
}
