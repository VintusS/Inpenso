//
//  HomeView.swift
//  iExpense
//
//  Created by Dragomir Mindrescu on 27.04.2025.
//

import SwiftUI
import Charts

struct HomeViewTest: View {
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
                    recentSpendingCard
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
    
}

#Preview {
    HomeViewTest(
        viewModel: ExpenseViewModel(),
        analyticsViewModel: AnalyticsViewModel(expenses: [])
    )
}
