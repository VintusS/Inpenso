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
    @State private var selectedDateIndex: Int = 0
    @State private var showSaveBudgetSuccess: Bool = false
    
    private let monthsPerYear = 12
    private let yearRange = 5
    
    enum AnalyticsTab {
        case overview
        case trends
        case insights
        case budget
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Month Year Picker
                monthYearPicker
                    .padding(.bottom, 8)
                
                // Tab Selection
                tabSelectionView
                    .padding(.horizontal)
                
                // Content based on selected tab
                ScrollView {
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
            }
            .navigationTitle("Analytics")
            .onAppear {
                syncSelectedDateIndex()
            }
            .alert("Budget Saved", isPresented: $showSaveBudgetSuccess) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Your monthly budget has been saved successfully.")
            }
        }
    }
    
    // MARK: - Tab Selection View
    
    private var tabSelectionView: some View {
        HStack(spacing: 2) {
            tabButton(title: "Overview", tab: .overview)
            tabButton(title: "Trends", tab: .trends)
            tabButton(title: "Insights", tab: .insights)
            tabButton(title: "Budget", tab: .budget)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(10)
    }
    
    private func tabButton(title: String, tab: AnalyticsTab) -> some View {
        Button(action: {
            withAnimation {
                selectedTab = tab
            }
        }) {
            Text(title)
                .font(.caption)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .fontWeight(selectedTab == tab ? .semibold : .regular)
                .padding(.vertical, 8)
                .padding(.horizontal, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(selectedTab == tab ? Color.accentColor : Color.clear)
                )
                .foregroundColor(selectedTab == tab ? .white : .primary)
        }
        .buttonStyle(PlainButtonStyle())
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Month Year Picker
    
    private var monthYearPicker: some View {
        TabView(selection: $selectedDateIndex) {
            ForEach(generateMonthYearList().indices, id: \.self) { index in
                let monthYear = generateMonthYearList()[index]
                let month = monthYear.month
                let year = monthYear.year

                Text("\(Calendar.current.monthSymbols[month - 1]) \(String(year))")
                    .font(.title2)
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
                    .tag(index)
            }
        }
        .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
        .frame(height: 60)
        .padding(.horizontal)
        .onChange(of: selectedDateIndex) { newIndex in
            let monthYearList = generateMonthYearList()
            
            let today = Date()
            let calendar = Calendar.current
            let todayMonth = calendar.component(.month, from: today)
            let todayYear = calendar.component(.year, from: today)
            
            if let todayIndex = monthYearList.firstIndex(where: { $0.month == todayMonth && $0.year == todayYear }) {
                
                if newIndex > todayIndex {
                    selectedDateIndex = todayIndex
                    triggerErrorHaptic()
                } else {
                    let monthYear = monthYearList[newIndex]
                    analyticsViewModel.selectedMonth = monthYear.month
                    analyticsViewModel.selectedYear = monthYear.year
                    analyticsViewModel.calculateAnalytics()
                    triggerHaptic()
                }
            }
        }
    }
    
    // MARK: - Overview Tab Content
    
    private var overviewTabContent: some View {
        VStack(spacing: 20) {
            // Summary Cards
            summaryCardsView
            
            // Daily Spending Graph
            dailySpendingGraphView
                .frame(height: 220)
            
            // Category Spending Breakdown
            categoryBreakdownView
        }
    }
    
    private var summaryCardsView: some View {
        let columns: [GridItem] = Array(repeating: .init(.flexible(), spacing: 12), count: 2)
        
        return LazyVGrid(columns: columns, spacing: 12) {
            // Total Spent
            summaryCard(
                title: "Total Spent",
                value: analyticsViewModel.totalSpent,
                valueFormat: .currency,
                icon: "dollarsign.circle.fill",
                color: .blue
            )

            // Daily Average
            summaryCard(
                title: "Daily Average",
                value: analyticsViewModel.averageDailySpend,
                valueFormat: .currency,
                icon: "calendar.badge.clock",
                color: .green
            )

            // Budget Used or No Budget
            if analyticsViewModel.currentBudget > 0 {
                let percentUsed = min(100, (analyticsViewModel.totalSpent / analyticsViewModel.currentBudget) * 100)
                summaryCard(
                    title: "Budget Used",
                    value: percentUsed,
                    valueFormat: .percent,
                    icon: "chart.pie.fill",
                    color: percentUsed >= 90 ? .red : (percentUsed >= 75 ? .orange : .blue)
                )
            } else {
                summaryCard(
                    title: "Budget",
                    value: 0,
                    valueFormat: .noBudget,
                    icon: "chart.pie.fill",
                    color: .gray
                )
            }

            // Remaining Per Day or Days Left
            if analyticsViewModel.currentBudget > 0 && analyticsViewModel.daysRemainingInMonth > 0 {
                summaryCard(
                    title: "Per Day Left",
                    value: analyticsViewModel.budgetRemainingPerDay,
                    valueFormat: .currency,
                    icon: "calendar.badge.clock",
                    color: .purple
                )
            } else {
                summaryCard(
                    title: "Days Left",
                    value: Double(analyticsViewModel.daysRemainingInMonth),
                    valueFormat: .days,
                    icon: "calendar",
                    color: .purple
                )
            }
        }
        .padding(.vertical)
        .frame(maxWidth: .infinity)
    }

    
    private enum ValueFormat {
        case currency
        case percent
        case days
        case noBudget
    }
    
    private func summaryCard(title: String, value: Double, valueFormat: ValueFormat, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // Title with icon
            HStack(alignment: .top, spacing: 6) {
                Image(systemName: icon)
                    .foregroundColor(color)

                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }

            Spacer()

            // Value display
            Group {
                switch valueFormat {
                case .currency:
                    Text(value, format: .currency(code: SettingsViewModel.getAppCurrency()))
                case .percent:
                    Text("\(Int(value))%")
                        .foregroundColor(value >= 90 ? .red : (value >= 75 ? .orange : .primary))
                case .days:
                    Text("\(Int(value)) days")
                case .noBudget:
                    Text("Not Set")
                        .foregroundColor(.gray)
                }
            }
            .font(.title3)
            .fontWeight(.bold)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
        }
        .padding()
        .frame(height: 110)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
    }

    
    private var dailySpendingGraphView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Daily Spending")
                .font(.headline)
            
            if analyticsViewModel.dailySpending.isEmpty {
                Text("No data available")
                    .foregroundColor(.secondary)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                Chart {
                    ForEach(analyticsViewModel.dailySpending, id: \.dayOfMonth) { daily in
                        BarMark(
                            x: .value("Day", daily.dayOfMonth),
                            y: .value("Amount", daily.amount)
                        )
                        .foregroundStyle(Color.blue.gradient)
                        .cornerRadius(4)
                    }
                    
                    if analyticsViewModel.averageDailySpend > 0 {
                        RuleMark(
                            y: .value("Average", analyticsViewModel.averageDailySpend)
                        )
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
                        .foregroundStyle(Color.green)
                        .annotation(position: .top, alignment: .trailing) {
                            Text("Avg")
                                .font(.caption)
                                .foregroundColor(.green)
                                .padding(4)
                                .background(Color(.secondarySystemBackground))
                                .cornerRadius(4)
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: 5)) { value in
                        AxisGridLine()
                        AxisValueLabel()
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
    }
    
    private var categoryBreakdownView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Spending by Category")
                .font(.headline)
            
            if analyticsViewModel.spendingByCategory.isEmpty {
                Text("No data available")
                    .foregroundColor(.secondary)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                VStack {
                    // Pie chart
                    Chart {
                        ForEach(analyticsViewModel.spendingByCategory.sorted(by: { $0.value > $1.value }), id: \.key) { category, amount in
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
                        ForEach(analyticsViewModel.spendingByCategory.sorted(by: { $0.value > $1.value }), id: \.key) { category, amount in
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
            if analyticsViewModel.totalSpent > 0 {
                VStack(alignment: .trailing) {
                    Text(amount, format: .currency(code: SettingsViewModel.getAppCurrency()))
                        .font(.subheadline)
                    
                    Text("\(Int((amount / analyticsViewModel.totalSpent) * 100))%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else {
                Text(amount, format: .currency(code: SettingsViewModel.getAppCurrency()))
                    .font(.subheadline)
            }
        }
    }
    
    // MARK: - Trends Tab Content
    
    private var trendsTabContent: some View {
        VStack(spacing: 20) {
            // Monthly Trends Graph
            monthlyTrendsGraphView
                .frame(height: 250)
            
            // Top Growing Categories
            categoryTrendsView
            
            // Monthly Projection
            if analyticsViewModel.projectedMonthlySpend > 0 {
                projectionView
            }
        }
    }
    
    private var monthlyTrendsGraphView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Monthly Spending")
                .font(.headline)
            
            if analyticsViewModel.monthlyTrends.isEmpty {
                Text("No data available")
                    .foregroundColor(.secondary)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                Chart {
                    ForEach(analyticsViewModel.monthlyTrends, id: \.month) { trend in
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
                .frame(height: 200)
                .chartYAxis {
                    AxisMarks(position: .leading) { _ in
                        AxisValueLabel(format: Decimal.FormatStyle.Percent.percent)
                    }
                }
            }
            
            if let firstTrend = analyticsViewModel.monthlyTrends.first,
               let lastTrend = analyticsViewModel.monthlyTrends.last,
               firstTrend.amount > 0, lastTrend.amount > 0 {
                let percentChange = ((lastTrend.amount - firstTrend.amount) / firstTrend.amount) * 100
                HStack {
                    Image(systemName: percentChange >= 0 ? "arrow.up.right" : "arrow.down.right")
                        .foregroundColor(percentChange >= 0 ? .red : .green)
                    
                    Text("\(abs(Int(percentChange)))% \(percentChange >= 0 ? "increase" : "decrease") over 6 months")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 8)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
    }
    
    private var categoryTrendsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Category Changes")
                .font(.headline)
            
            if analyticsViewModel.categoryTrends.isEmpty {
                Text("No data available for comparison")
                    .foregroundColor(.secondary)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                let sortedTrends = analyticsViewModel.categoryTrends
                    .filter { $0.previousAmount > 0 } // Only categories with previous month data
                    .sorted { abs($0.percentChange) > abs($1.percentChange) } // Sort by absolute percent change
                    .prefix(4) // Top 4 changes
                
                VStack(spacing: 10) {
                    ForEach(Array(sortedTrends.enumerated()), id: \.element.category) { _, trend in
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
                Text(trend.currentAmount, format: .currency(code: SettingsViewModel.getAppCurrency()))
                    .font(.caption)
                
                Text(trend.previousAmount, format: .currency(code: SettingsViewModel.getAppCurrency()))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var projectionView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Monthly Projection")
                .font(.headline)
            
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Projected")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text(analyticsViewModel.projectedMonthlySpend, format: .currency(code: SettingsViewModel.getAppCurrency()))
                        .font(.title3)
                        .fontWeight(.bold)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                if analyticsViewModel.currentBudget > 0 {
                    Divider()
                        .frame(height: 50)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Budget")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Text(analyticsViewModel.currentBudget, format: .currency(code: SettingsViewModel.getAppCurrency()))
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
                        
                        let difference = analyticsViewModel.projectedMonthlySpend - analyticsViewModel.currentBudget
                        Text(abs(difference), format: .currency(code: SettingsViewModel.getAppCurrency()))
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(difference > 0 ? .red : .green)
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
            
            if analyticsViewModel.currentBudget > 0 {
                let isOverBudget = analyticsViewModel.projectedMonthlySpend > analyticsViewModel.currentBudget
                
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
    
    // MARK: - Insights Tab Content
    
    private var insightsTabContent: some View {
        VStack(spacing: 20) {
            // Key stats at the top
            keySummaryView
            
            // Auto-generated insights
            insightsCardsView
            
            // Spending Pattern Analysis
            spendingPatternView
        }
    }
    
    private var keySummaryView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Key Statistics")
                .font(.headline)
            
            // Biggest expense category
            if let (category, amount) = analyticsViewModel.biggestExpenseCategory {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Top Spending Category")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        HStack {
                            Circle()
                                .fill(category.color)
                                .frame(width: 10, height: 10)
                            
                            Text(category.displayName)
                                .font(.system(size: 18, weight: .bold))
                        }
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        if analyticsViewModel.totalSpent > 0 {
                            Text("\(Int((amount / analyticsViewModel.totalSpent) * 100))% of total")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Text(amount, format: .currency(code: SettingsViewModel.getAppCurrency()))
                            .font(.system(size: 18, weight: .bold))
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.secondarySystemBackground))
                )
            }
            
            // Most active spending period
            let activePeriod = findMostActiveSpendingPeriod()
            if let period = activePeriod {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Most Active Days")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Text(period)
                            .font(.system(size: 18, weight: .bold))
                    }
                    
                    Spacer()
                    
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 24))
                        .foregroundColor(.blue)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.secondarySystemBackground))
                )
            }
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
    
    private var insightsCardsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Smart Insights")
                .font(.headline)
            
            if analyticsViewModel.insights.isEmpty {
                Text("No insights available yet")
                    .foregroundColor(.secondary)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .center)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.secondarySystemBackground))
                    )
            } else {
                ForEach(analyticsViewModel.insights, id: \.title) { insight in
                    insightCard(insight: insight)
                }
            }
        }
    }
    
    private func insightCard(insight: SpendingInsight) -> some View {
        HStack(spacing: 16) {
            // Icon
            Image(systemName: insight.icon)
                .font(.system(size: 28))
                .foregroundColor(insight.color)
                .frame(width: 36)
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(insight.title)
                    .font(.headline)
                
                Text(insight.description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
    }
    
    private var spendingPatternView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Spending Patterns")
                .font(.headline)
            
            if analyticsViewModel.dailySpending.isEmpty {
                Text("Not enough data")
                    .foregroundColor(.secondary)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                // Analyze weekdays vs weekends
                let weekdayVsWeekendAnalysis = analyzeWeekdayVsWeekend()
                
                if let analysis = weekdayVsWeekendAnalysis {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Weekday vs Weekend")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            Text(analysis.title)
                                .font(.system(size: 16, weight: .semibold))
                            
                            Text(analysis.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: analysis.icon)
                            .font(.system(size: 24))
                            .foregroundColor(analysis.color)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.tertiarySystemBackground))
                    )
                }
                
                // Analyze beginning vs end of month
                let monthAnalysis = analyzeMonthlyPattern()
                
                if let analysis = monthAnalysis {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Monthly Pattern")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            Text(analysis.title)
                                .font(.system(size: 16, weight: .semibold))
                            
                            Text(analysis.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: analysis.icon)
                            .font(.system(size: 24))
                            .foregroundColor(analysis.color)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.tertiarySystemBackground))
                    )
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
    }
    
    private struct PatternAnalysis {
        let title: String
        let description: String
        let icon: String
        let color: Color
    }
    
    private func analyzeWeekdayVsWeekend() -> PatternAnalysis? {
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
            return PatternAnalysis(
                title: "Weekend Spender",
                description: "You spend \(Int(ratio * 100))% more on weekends compared to weekdays",
                icon: "party.popper",
                color: .orange
            )
        } else if ratio > 1.1 {
            return PatternAnalysis(
                title: "Slightly Higher Weekend Spending",
                description: "Your weekend spending is moderately higher than weekdays",
                icon: "calendar.badge.plus",
                color: .blue
            )
        } else if ratio < 0.7 {
            return PatternAnalysis(
                title: "Weekday Focused",
                description: "You spend significantly more on weekdays than weekends",
                icon: "briefcase",
                color: .purple
            )
        } else {
            return PatternAnalysis(
                title: "Balanced Spending",
                description: "Your spending is fairly consistent throughout the week",
                icon: "equal.circle",
                color: .green
            )
        }
    }
    
    private func analyzeMonthlyPattern() -> PatternAnalysis? {
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
            return PatternAnalysis(
                title: "Early Month Spender",
                description: "You tend to spend more in the first part of the month",
                icon: "calendar.badge.plus",
                color: .green
            )
        } else if maxAvg == lateAvg && lateAvg > earlyAvg * 1.3 && lateAvg > midAvg * 1.3 {
            return PatternAnalysis(
                title: "End of Month Spender",
                description: "Your spending increases toward the end of the month",
                icon: "calendar.badge.exclamationmark",
                color: .red
            )
        } else if maxAvg == midAvg && midAvg > earlyAvg * 1.3 && midAvg > lateAvg * 1.3 {
            return PatternAnalysis(
                title: "Mid-Month Spike",
                description: "Your spending peaks in the middle of the month",
                icon: "waveform.path.ecg",
                color: .orange
            )
        } else {
            return PatternAnalysis(
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
            budgetInputView
            
            // Budget Status
            if analyticsViewModel.currentBudget > 0 {
                budgetStatusView
                
                // Budget recommendations
                budgetRecommendationsView
            }
            
            // Historical budget compliance
            historicalBudgetView
        }
    }
    
    private var budgetInputView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Set Monthly Budget")
                .font(.headline)
            
            VStack(spacing: 16) {
                HStack {
                    Text("Budget Amount")
                        .font(.subheadline)

                    Spacer()

                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(.tertiarySystemBackground))
                            .frame(width: 150, height: 40)
                        
                        TextField("0", value: $analyticsViewModel.currentBudget, format: .currency(code: SettingsViewModel.getAppCurrency()))
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .padding(.horizontal, 10)
                            .frame(width: 150, height: 40)
                    }
                    .toolbar {
                        ToolbarItemGroup(placement: .keyboard) {
                            Spacer()
                            Button("Done") {
                                hideKeyboard()
                            }
                        }
                    }
                }

                Button(action: {
                    saveBudget()
                }) {
                    Text("Save Budget")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.secondarySystemBackground))
            )
        }
    }
    
    private var budgetStatusView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Budget Status")
                .font(.headline)
            
            VStack(spacing: 16) {
                // Progress bar
                let progress = min(1.0, analyticsViewModel.totalSpent / analyticsViewModel.currentBudget)
                let progressColor: Color = progress < 0.75 ? .blue : (progress < 0.9 ? .orange : .red)
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("\(Int(progress * 100))% Used")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text("\(Int((1 - progress) * 100))% Remaining")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            // Background
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color(.systemGray5))
                                .frame(height: 12)
                            
                            // Progress
                            RoundedRectangle(cornerRadius: 6)
                                .fill(progressColor)
                                .frame(width: geometry.size.width * CGFloat(progress), height: 12)
                        }
                    }
                    .frame(height: 12)
                }
                
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Spent")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(analyticsViewModel.totalSpent, format: .currency(code: SettingsViewModel.getAppCurrency()))
                            .font(.title3)
                            .fontWeight(.bold)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Remaining")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(max(0, analyticsViewModel.currentBudget - analyticsViewModel.totalSpent), format: .currency(code: SettingsViewModel.getAppCurrency()))
                            .font(.title3)
                            .fontWeight(.bold)
                    }
                }
                
                if analyticsViewModel.daysRemainingInMonth > 0 {
                    Divider()
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Days Remaining")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text("\(analyticsViewModel.daysRemainingInMonth) days")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("Daily Budget Left")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text(analyticsViewModel.budgetRemainingPerDay, format: .currency(code: SettingsViewModel.getAppCurrency()))
                                .font(.subheadline)
                                .fontWeight(.semibold)
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
    }
    
    private var budgetRecommendationsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recommendations")
                .font(.headline)
            
            VStack(spacing: 16) {
                // Recommend categories to cut
                if let (category, amount) = analyticsViewModel.biggestExpenseCategory, 
                   analyticsViewModel.totalSpent > analyticsViewModel.currentBudget {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Consider Reducing")
                                .font(.subheadline)
                            
                            HStack {
                                Circle()
                                    .fill(category.color)
                                    .frame(width: 8, height: 8)
                                
                                Text(category.displayName)
                                    .font(.system(size: 15, weight: .semibold))
                            }
                        }
                        
                        Spacer()
                        
                        Text(amount, format: .currency(code: SettingsViewModel.getAppCurrency()))
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .padding(.horizontal)
                }
                
                // Daily spending target when over budget
                if analyticsViewModel.totalSpent > analyticsViewModel.currentBudget && analyticsViewModel.daysRemainingInMonth > 0 {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("To Get Back on Track")
                            .font(.subheadline)
                        
                        Text("You need to spend \(analyticsViewModel.currentBudget * 0.9 - analyticsViewModel.totalSpent, format: .currency(code: SettingsViewModel.getAppCurrency())) less than budgeted for the rest of the month.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                }
                
                // Suggested next month's budget based on trends
                let suggestedBudget = calculateSuggestedBudget()
                if suggestedBudget > 0 && abs(suggestedBudget - analyticsViewModel.currentBudget) / analyticsViewModel.currentBudget > 0.1 {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Suggested Next Month")
                            .font(.subheadline)
                        
                        HStack {
                            Text(suggestedBudget, format: .currency(code: SettingsViewModel.getAppCurrency()))
                                .font(.system(size: 15, weight: .semibold))
                            
                            if suggestedBudget > analyticsViewModel.currentBudget {
                                Text("(+\(Int((suggestedBudget - analyticsViewModel.currentBudget) / analyticsViewModel.currentBudget * 100))%)")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            } else {
                                Text("(-\(Int((analyticsViewModel.currentBudget - suggestedBudget) / analyticsViewModel.currentBudget * 100))%)")
                                    .font(.caption)
                                    .foregroundColor(.green)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.secondarySystemBackground))
            )
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
    
    private var historicalBudgetView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Budget History")
                .font(.headline)
            
            // Check if we have enough budget history
            if analyticsViewModel.monthlyTrends.count < 2 {
                Text("Not enough budget history yet")
                    .foregroundColor(.secondary)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .center)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.secondarySystemBackground))
                    )
            } else {
                // Create budget compliance chart
                let complianceData = createBudgetComplianceData()
                
                if complianceData.isEmpty {
                    Text("No budget data for previous months")
                        .foregroundColor(.secondary)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .center)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.secondarySystemBackground))
                        )
                } else {
                    VStack {
                        Chart {
                            ForEach(complianceData, id: \.month) { data in
                                BarMark(
                                    x: .value("Month", data.monthName),
                                    y: .value("Percent", data.compliancePercent)
                                )
                                .foregroundStyle(data.color)
                                .cornerRadius(4)
                            }
                            
                            // Budget line with properly positioned label
                            RuleMark(y: .value("Budget", 100))
                                .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
                                .foregroundStyle(Color.gray)
                                .annotation(position: .trailing, alignment: .leading, spacing: 4) {
                                    Text("Budget")
                                        .font(.caption2)
                                        .foregroundColor(.gray)
                                        .padding(.trailing, 8)
                                }
                        }
                        .frame(height: 200)
                        .chartYAxis {
                            AxisMarks(position: .leading) { _ in
                                AxisValueLabel(format: Decimal.FormatStyle.Percent.percent)
                            }
                        }
                        
                        // Summary text
                        let onBudgetMonths = complianceData.filter { $0.compliancePercent <= 100 }.count
                        let totalMonths = complianceData.count
                        
                        Text("\(onBudgetMonths) of \(totalMonths) months on or under budget")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.top, 8)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.secondarySystemBackground))
                    )
                }
            }
        }
    }
    
    private struct BudgetComplianceData {
        let month: Int
        let year: Int
        let monthName: String
        let compliancePercent: Double
        let color: Color
    }
    
    private func createBudgetComplianceData() -> [BudgetComplianceData] {
        var result: [BudgetComplianceData] = []
        
        // Skip the current month and use previous months
        for trend in analyticsViewModel.monthlyTrends.dropLast() {
            let key = analyticsViewModel.budgetKey(forMonth: trend.month, year: trend.year)
            if let budget = analyticsViewModel.monthlyBudgets[key], budget > 0 {
                let compliancePercent = (trend.amount / budget) * 100
                let color: Color = compliancePercent <= 90 ? .green : 
                                    (compliancePercent <= 100 ? .blue : 
                                    (compliancePercent <= 110 ? .orange : .red))
                
                result.append(BudgetComplianceData(
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
    
    private func syncSelectedDateIndex() {
        let currentYear = Calendar.current.component(.year, from: Date())
        let currentMonth = Calendar.current.component(.month, from: Date())
        selectedDateIndex = (currentYear - (Calendar.current.component(.year, from: Date()) - yearRange)) * monthsPerYear + (currentMonth - 1)
    }

    private func generateMonthYearList() -> [(month: Int, year: Int)] {
        let currentYear = Calendar.current.component(.year, from: Date())
        var monthsYears: [(Int, Int)] = []

        for year in (currentYear - yearRange)...(currentYear + yearRange) {
            for month in 1...12 {
                monthsYears.append((month, year))
            }
        }
        return monthsYears
    }
    
    private func saveBudget() {
        let key = analyticsViewModel.budgetKey(forMonth: analyticsViewModel.selectedMonth, year: analyticsViewModel.selectedYear)
        analyticsViewModel.monthlyBudgets[key] = analyticsViewModel.currentBudget
        StorageService.saveBudgets(analyticsViewModel.monthlyBudgets)
        showSaveBudgetSuccess = true
    }

    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    private func triggerErrorHaptic() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.error)
    }
    
    private func triggerHaptic() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }
}

// MARK: - Refactoring Note for Future Component Structure
/*
This file could be restructured into separate components:
1. Create an "AnalyticsComponents" directory with these files:
   - SummaryCardView.swift (for the summary cards component)
   - DailySpendingChartView.swift (for the daily spending chart)
   - CategoryBreakdownView.swift (for category breakdown)
   - MonthlyTrendsView.swift (for monthly trends)
   - InsightsCardView.swift (for insights)
   - BudgetStatusView.swift (for budget status)
   
2. AnalyticsView would then import and use these components
   with cleaner, more maintainable code organization
*/

#Preview {
    AnalyticsView(analyticsViewModel: AnalyticsViewModel(expenses: []))
}
