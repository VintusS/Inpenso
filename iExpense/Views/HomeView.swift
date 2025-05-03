//
//  HomeView.swift
//  iExpense
//
//  Created by Dragomir Mindrescu on 27.04.2025.
//

import SwiftUI
import Charts

struct HomeView: View {
    @ObservedObject var viewModel: ExpenseViewModel
    @ObservedObject var analyticsViewModel: AnalyticsViewModel
    @State private var showingAddExpense = false
    @State private var showRecentExpenses = true
    @State private var animateCards = false
    @State private var selectedExpenseToEdit: Expense? = nil
    @State private var showingEditExpense = false
    
    private let recentDaysToShow = 7
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Header summary card
                    headerCard
                        .padding(.top, 10)
                    
                    // Recent spending trend
                    recentSpendingCard
                    
                    // Category breakdown
                    categoryBreakdownCard
                    
                    // Recent expenses section
                    recentExpensesSection
                }
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
            .navigationTitle("Home")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingAddExpense = true
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "plus")
                            Text("Add")
                                .font(.callout)
                                .fontWeight(.semibold)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(20)
                    }
                }
            }
            .sheet(isPresented: $showingAddExpense) {
                AddExpenseView(viewModel: viewModel)
            }
            .sheet(item: $selectedExpenseToEdit) { expense in
                EditExpenseView(viewModel: viewModel, expense: expense)
            }
            .onAppear {
                // Animate cards when view appears with slight delay between each
                withAnimation(.easeOut(duration: 0.5).delay(0.1)) {
                    animateCards = true
                }
            }
        }
    }
    
    // MARK: - Header Card
    
    private var headerCard: some View {
        VStack(spacing: 16) {
            // Total display
            VStack(spacing: 4) {
                Text("Total Spent This Month")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                Text(analyticsViewModel.totalSpent, format: .currency(code: SettingsViewModel.getAppCurrency()))
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
            }
            
            // Budget information if available
            if analyticsViewModel.currentBudget > 0 {
                VStack(spacing: 8) {
                    // Progress bar
                    let progress = min(1.0, analyticsViewModel.totalSpent / analyticsViewModel.currentBudget)
                    let progressColor: Color = progress < 0.75 ? .blue : (progress < 0.9 ? .orange : .red)
                    
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            // Background
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color(.systemGray5))
                                .frame(height: 8)
                            
                            // Progress
                            RoundedRectangle(cornerRadius: 6)
                                .fill(progressColor)
                                .frame(width: geometry.size.width * CGFloat(progress), height: 8)
                        }
                    }
                    .frame(height: 8)
                    
                    // Budget info
                    HStack {
                        Text("\(Int(progress * 100))% of budget")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text("\(analyticsViewModel.daysRemainingInMonth) days left")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.secondarySystemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
        )
        .offset(y: animateCards ? 0 : -50)
        .opacity(animateCards ? 1 : 0)
    }
    
    // MARK: - Recent Spending Card
    
    private var recentSpendingCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Recent Spending")
                .font(.headline)
            
            if analyticsViewModel.dailySpending.isEmpty {
                Text("No recent spending data")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical)
            } else {
                // Get most recent spending data from the daily spending array
                let recentSpending: [DailySpending] = getRecentSpendingData()
                
                // Check if we have any actual spending in this period
                let totalRecentSpending = recentSpending.reduce(0.0) { $0 + $1.amount }
                
                if totalRecentSpending <= 0 {
                    Text("No spending in the last \(recentDaysToShow) days")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical)
                } else {
                    // Find max value for better scaling
                    let maxValue = recentSpending.map { $0.amount }.max() ?? 0
                    
                    VStack(spacing: 8) {
                        Chart {
                            ForEach(recentSpending, id: \.dayOfMonth) { daily in
                                BarMark(
                                    x: .value("Day", daily.weekday),
                                    y: .value("Amount", daily.amount)
                                )
                                .foregroundStyle(
                                    .linearGradient(
                                        colors: [.blue.opacity(0.7), .blue],
                                        startPoint: .bottom,
                                        endPoint: .top
                                    )
                                )
                                .cornerRadius(6)
                            }
                            
                            if analyticsViewModel.averageDailySpend > 0 {
                                RuleMark(
                                    y: .value("Average", analyticsViewModel.averageDailySpend)
                                )
                                .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 5]))
                                .foregroundStyle(Color.green)
                                .annotation(position: .top, alignment: .trailing) {
                                    Text("Avg")
                                        .font(.caption2)
                                        .foregroundColor(.green)
                                        .padding(4)
                                        .background(Color(.tertiarySystemBackground))
                                        .cornerRadius(4)
                                }
                            }
                        }
                        .frame(height: 180)
                        .chartYAxis {
                            AxisMarks(position: .leading)
                        }
                        // Enforce minimum scale if values are very small
                        .chartYScale(domain: 0...(max(maxValue * 1.2, analyticsViewModel.averageDailySpend * 1.2, 1)))
                        
                        // Add a note about the data
                        Text("Showing spending for the last \(recentDaysToShow) days")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.secondarySystemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
        )
        .offset(y: animateCards ? 0 : -30)
        .opacity(animateCards ? 1 : 0)
    }
    
    // Helper function to get recent spending data
    private func getRecentSpendingData() -> [DailySpending] {
        var recentSpending: [DailySpending] = []
        
        // For debugging and comprehensive data, let's look at all daily spending
        let allDays = analyticsViewModel.dailySpending
        
        // Find the last 7 days, including today
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        for i in 0..<recentDaysToShow {
            if let date = calendar.date(byAdding: .day, value: -i, to: today) {
                // Find the matching day in our data
                if let day = allDays.first(where: { calendar.isDate($0.date, inSameDayAs: date) }) {
                    recentSpending.insert(day, at: 0) // Insert at front to maintain chronological order
                }
            }
        }
        
        return recentSpending
    }
    
    // MARK: - Category Breakdown Card
    
    private var categoryBreakdownCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Spending by Category")
                .font(.headline)
            
            if analyticsViewModel.spendingByCategory.isEmpty {
                Text("No category data available")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical)
            } else {
                let sortedCategories = analyticsViewModel.spendingByCategory
                    .sorted(by: { $0.value > $1.value })
                    .prefix(5) // Show top 5 categories
                
                VStack(spacing: 12) {
                    ForEach(Array(sortedCategories), id: \.key) { category, amount in
                        HStack(spacing: 12) {
                            // Icon and category
                            HStack(spacing: 8) {
                                Image(systemName: categoryIcon(for: category))
                                    .font(.system(size: 16))
                                    .foregroundColor(.white)
                                    .frame(width: 30, height: 30)
                                    .background(category.color)
                                    .cornerRadius(8)
                                
                                Text(category.displayName)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                            }
                            
                            Spacer()
                            
                            // Amount and percentage
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(amount, format: .currency(code: SettingsViewModel.getAppCurrency()))
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                
                                if analyticsViewModel.totalSpent > 0 {
                                    Text("\(Int((amount / analyticsViewModel.totalSpent) * 100))%")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        
                        if category != sortedCategories.last?.key {
                            Divider()
                        }
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.secondarySystemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
        )
        .offset(y: animateCards ? 0 : -20)
        .opacity(animateCards ? 1 : 0)
    }
    
    // MARK: - Recent Expenses Section
    
    private var recentExpensesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent Expenses")
                    .font(.headline)
                
                Spacer()
                
                Button(action: {
                    withAnimation {
                        showRecentExpenses.toggle()
                    }
                }) {
                    Label(showRecentExpenses ? "Hide" : "Show", systemImage: showRecentExpenses ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            if showRecentExpenses {
                if viewModel.expenses.isEmpty {
                    Text("No expenses yet")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical)
                } else {
                    // Show most recent 5 expenses
                    let recentExpenses = viewModel.expenses.sorted { $0.date > $1.date }.prefix(5)
                    
                    ForEach(recentExpenses) { expense in
                        Button {
                            selectedExpenseToEdit = expense
                            showingEditExpense = true
                        } label: {
                            HStack(spacing: 12) {
                                // Category icon
                                Image(systemName: categoryIcon(for: expense.category))
                                    .font(.system(size: 14))
                                    .foregroundColor(.white)
                                    .frame(width: 28, height: 28)
                                    .background(expense.category.color)
                                    .cornerRadius(6)
                                
                                // Title and date
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(expense.title)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(.primary)
                                    
                                    Text(expense.date, style: .date)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                // Amount
                                Text(expense.price, format: .currency(code: SettingsViewModel.getAppCurrency()))
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primary)
                            }
                            .padding(.vertical, 8)
                        }
                        
                        if expense.id != recentExpenses.last?.id {
                            Divider()
                                .padding(.leading, 40)
                        }
                    }
                    
                    // View all button
                    Button(action: {
                        // Use NotificationCenter to notify MainTabView to switch to expenses tab
                        NotificationCenter.default.post(name: NSNotification.Name("SwitchToExpensesTab"), object: nil)
                    }) {
                        Text("View All Expenses")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.accentColor)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.accentColor, lineWidth: 1.5)
                            )
                            .padding(.top, 8)
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.secondarySystemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
        )
        .offset(y: animateCards ? 0 : -10)
        .opacity(animateCards ? 1 : 0)
    }
    
    // MARK: - Helper Methods
    
    private func categoryIcon(for category: Category) -> String {
        switch category {
        case .food:
            return "cart.fill"
        case .eatingOut:
            return "fork.knife"
        case .rent:
            return "house.fill"
        case .shopping:
            return "bag.fill"
        case .entertainment:
            return "tv.fill"
        case .transportation:
            return "car.fill"
        case .utilities:
            return "bolt.fill"
        case .subscriptions:
            return "repeat"
        case .healthcare:
            return "heart.fill"
        case .education:
            return "book.fill"
        case .others:
            return "ellipsis"
        }
    }
}

#Preview {
    HomeView(
        viewModel: ExpenseViewModel(),
        analyticsViewModel: AnalyticsViewModel(expenses: [])
    )
}
