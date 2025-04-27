//
//  AnalyticsViewModel.swift
//  iExpense
//
//  Created by Dragomir Mindrescu on 27.04.2025.
//

import Foundation

@MainActor
class AnalyticsViewModel: ObservableObject {
    @Published private(set) var totalSpent: Double = 0.0
    @Published private(set) var spendingByCategory: [Category: Double] = [:]
    
    @Published var selectedMonth: Int = Calendar.current.component(.month, from: Date())
    @Published var selectedYear: Int = Calendar.current.component(.year, from: Date())
    
    @Published var monthlyBudgets: [String: Double] = [:]
    @Published var currentBudget: Double = 0.0
    
    private var expenses: [Expense] = []

    init(expenses: [Expense]) {
        self.expenses = expenses
        calculateAnalytics()
    }
    
    func updateExpenses(_ expenses: [Expense]) {
        self.expenses = expenses
        calculateAnalytics()
    }
    
    func calculateAnalytics() {
        let filteredExpenses = expenses.filter { expense in
            let expenseMonth = Calendar.current.component(.month, from: expense.date)
            let expenseYear = Calendar.current.component(.year, from: expense.date)
            return expenseMonth == selectedMonth && expenseYear == selectedYear
        }
        
        totalSpent = filteredExpenses.reduce(0) { $0 + $1.amount }
        
        var categoryTotals: [Category: Double] = [:]
        for expense in filteredExpenses {
            categoryTotals[expense.category, default: 0] += expense.amount
        }
        spendingByCategory = categoryTotals
        
        let key = budgetKey(forMonth: selectedMonth, year: selectedYear)
        currentBudget = monthlyBudgets[key] ?? 0.0
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
