//
//  AnalyticsView+Analysis.swift
//  iExpense
//

import SwiftUI

// MARK: - Spending analysis

extension AnalyticsView {
    func findMostActiveSpendingPeriod() -> String? {
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
    
    func analyzeWeekdayVsWeekend() -> SpendingPatternView.PatternAnalysis? {
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
    
    func analyzeMonthlyPattern() -> SpendingPatternView.PatternAnalysis? {
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

    func calculateSuggestedBudget() -> Double {
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
    
    func createBudgetComplianceData() -> [BudgetHistoryView.BudgetComplianceData] {
        var result: [BudgetHistoryView.BudgetComplianceData] = []
        
        // Skip the current month and use previous months
        for trend in analyticsViewModel.monthlyTrends.dropLast() {
            let budget = StorageService.effectiveBudget(month: trend.month, year: trend.year, in: analyticsViewModel.monthlyBudgets)
            if budget > 0 {
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
}
