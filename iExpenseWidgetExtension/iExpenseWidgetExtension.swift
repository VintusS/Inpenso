// iExpenseWidgetExtension.swift
// iExpenseWidgetExtension

import WidgetKit
import SwiftUI
import AppIntents
import Foundation

// Global app group ID for consistency - must match StorageService.appGroupID
let appGroupID = "group.com.vintuss.iexpense"

// Global function to get currency code from shared UserDefaults
func getAppCurrency() -> String {
    // First try to get from shared defaults with explicit initialization
    let sharedDefaults = UserDefaults(suiteName: appGroupID)
    
    if let sharedDefaults = sharedDefaults {
        // Force a synchronize before reading
        sharedDefaults.synchronize()
        
        // Try to read the currency directly
        if let currency = sharedDefaults.string(forKey: "selectedCurrency") {
            return currency
        }
    }
    
    // If we got here, try standard UserDefaults
    let standardDefaults = UserDefaults.standard
    standardDefaults.synchronize()
    let standardCurrency = standardDefaults.string(forKey: "selectedCurrency")
    
    // If all else fails, return USD
    return standardCurrency ?? "USD"
}

// Get monthly budget from shared UserDefaults
func getMonthlyBudget() -> Double {
    let sharedDefaults = UserDefaults(suiteName: appGroupID)
    
    if let sharedDefaults = sharedDefaults {
        // Force a synchronize before reading
        sharedDefaults.synchronize()
        
        // Get the budgets data
        if let budgetsData = sharedDefaults.data(forKey: "budgets") {
            do {
                let budgets = try JSONDecoder().decode([String: Double].self, from: budgetsData)
                
                // Get current month in format "MM-YYYY"
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "MM-yyyy"
                let currentMonthKey = dateFormatter.string(from: Date())
                
                // Return the budget for the current month
                return budgets[currentMonthKey] ?? 0
            } catch {
                return 0
            }
        }
    }
    
    return 0
}

struct ExpenseEntry: TimelineEntry {
    let date: Date
    let totalSpent: Double
    let spendingByCategory: [Category: Double]
    let monthlyBudget: Double
    
    // Computed properties for the widget
    var budgetRemaining: Double {
        max(0, monthlyBudget - totalSpent)
    }
    
    var budgetProgress: Double {
        monthlyBudget > 0 ? min(1.0, totalSpent / monthlyBudget) : 0
    }
    
    var topCategories: [(Category, Double)] {
        Array(spendingByCategory.sorted { $0.value > $1.value }.prefix(5))
    }
    
    var overBudget: Bool {
        monthlyBudget > 0 && totalSpent > monthlyBudget
    }
    
    var daysLeftInMonth: Int {
        let calendar = Calendar.current
        let today = calendar.component(.day, from: Date())
        
        // Get range of days in current month
        let range = calendar.range(of: .day, in: .month, for: Date())!
        let daysInMonth = range.count
        
        return daysInMonth - today
    }
    
    var dailyBudgetRecommendation: Double {
        if daysLeftInMonth > 0 && monthlyBudget > 0 {
            return budgetRemaining / Double(daysLeftInMonth)
        }
        return 0
    }
}

struct ExpenseQuickAddProvider: AppIntentTimelineProvider {
    typealias Intent = QuickAddConfigurationIntent
    
    // Use the shared app group
    private let sharedDefaults = UserDefaults(suiteName: appGroupID)

    func placeholder(in context: Context) -> ExpenseEntry {
        ExpenseEntry(
            date: Date(), 
            totalSpent: 0, 
            spendingByCategory: [:],
            monthlyBudget: 0
        )
    }

    func snapshot(for configuration: QuickAddConfigurationIntent, in context: Context) async -> ExpenseEntry {
        await loadEntry()
    }

    func timeline(for configuration: QuickAddConfigurationIntent, in context: Context) async -> Timeline<ExpenseEntry> {
        let entry = await loadEntry()
        let timeline = Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(1800))) // refresh every 30min
        return timeline
    }

    private func loadEntry() async -> ExpenseEntry {
        let expenses = StorageService.loadExpenses()
        let monthlyBudget = getMonthlyBudget()

        let calendar = Calendar.current
        let currentMonth = calendar.component(.month, from: Date())
        let currentYear = calendar.component(.year, from: Date())

        let filteredExpenses = expenses.filter { expense in
            let month = calendar.component(.month, from: expense.date)
            let year = calendar.component(.year, from: expense.date)
            return month == currentMonth && year == currentYear
        }

        let total = filteredExpenses.reduce(0) { $0 + $1.price }

        var categoryTotals: [Category: Double] = [:]
        for expense in filteredExpenses {
            categoryTotals[expense.category, default: 0] += expense.price
        }

        return ExpenseEntry(
            date: Date(), 
            totalSpent: total, 
            spendingByCategory: categoryTotals,
            monthlyBudget: monthlyBudget
        )
    }
}

// MARK: - Widget Views
struct iExpenseWidgetEntryView: View {
    var entry: ExpenseEntry
    @Environment(\.widgetFamily) var family
    let currencyCode = getAppCurrency()
    
    var body: some View {
        switch family {
        case .systemSmall:
            smallWidget
        case .systemMedium:
            mediumWidget
        case .systemLarge:
            largeWidget
        default:
            smallWidget
        }
    }
    
    // MARK: - Small Widget
    var smallWidget: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header with month spending
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("This Month")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(entry.totalSpent, format: .currency(code: currencyCode))
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(entry.overBudget ? .red : .primary)
                }
                
                Spacer()
                
                // Circular progress indicator
                ZStack {
                    Circle()
                        .stroke(Color(.systemGray5), lineWidth: 4)
                        .frame(width: 40, height: 40)
                    
                    if entry.monthlyBudget > 0 {
                        Circle()
                            .trim(from: 0, to: entry.budgetProgress)
                            .stroke(
                                entry.overBudget ? Color.red : Color.blue,
                                style: StrokeStyle(lineWidth: 4, lineCap: .round)
                            )
                            .frame(width: 40, height: 40)
                            .rotationEffect(.degrees(-90))
                        
                        Text("\(Int(entry.budgetProgress * 100))%")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(entry.overBudget ? .red : .primary)
                    } else {
                        Image(systemName: "infinity")
                            .font(.system(size: 14, weight: .bold))
                    }
                }
            }
            
            if entry.monthlyBudget > 0 {
                Divider()
                
                HStack {
                    Text(entry.overBudget ? "Over by" : "Left")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    if entry.overBudget {
                        Text(entry.totalSpent - entry.monthlyBudget, format: .currency(code: currencyCode))
                            .font(.caption)
                            .foregroundColor(.red)
                            .fontWeight(.semibold)
                    } else {
                        Text(entry.budgetRemaining, format: .currency(code: currencyCode))
                            .font(.caption)
                            .foregroundColor(.blue)
                            .fontWeight(.semibold)
                    }
                }
            }
            
            if let topCategory = entry.topCategories.first {
                HStack {
                    Circle()
                        .fill(topCategory.0.color)
                        .frame(width: 8, height: 8)
                    
                    Text("Top: \(topCategory.0.displayName)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text(topCategory.1, format: .currency(code: currencyCode))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(12)
    }
    
    // MARK: - Medium Widget
    var mediumWidget: some View {
        HStack {
            // Left section - Spending & Budget
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("This Month")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(entry.totalSpent, format: .currency(code: currencyCode))
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(entry.overBudget ? .red : .primary)
                    }
                    
                    Spacer()
                    
                    if entry.monthlyBudget > 0 {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("Budget")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text(entry.monthlyBudget, format: .currency(code: currencyCode))
                                .font(.callout)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // Budget progress bar
                if entry.monthlyBudget > 0 {
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color(.systemGray5))
                                .frame(height: 8)
                            
                            RoundedRectangle(cornerRadius: 4)
                                .fill(entry.overBudget ? Color.red : Color.blue)
                                .frame(width: min(CGFloat(entry.budgetProgress) * geometry.size.width, geometry.size.width), height: 8)
                        }
                    }
                    .frame(height: 8)
                    
                    HStack {
                        if entry.overBudget {
                            Text("Over by")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            
                            Text(entry.totalSpent - entry.monthlyBudget, format: .currency(code: currencyCode))
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.red)
                        } else {
                            Text("\(entry.daysLeftInMonth) days left")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            Text(entry.budgetRemaining, format: .currency(code: currencyCode))
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.blue)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.trailing, 8)
            
            // Right section - Top categories
            VStack(alignment: .leading, spacing: 4) {
                Text("Top Categories")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if entry.topCategories.isEmpty {
                    Text("No data")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 8)
                } else {
                    VStack(spacing: 6) {
                        ForEach(entry.topCategories.prefix(3), id: \.0) { category, amount in
                            HStack {
                                Circle()
                                    .fill(category.color)
                                    .frame(width: 8, height: 8)
                                
                                Text(category.displayName)
                                    .font(.caption2)
                                    .lineLimit(1)
                                
                                Spacer()
                                
                                Text(amount, format: .currency(code: currencyCode))
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                
                Spacer()
                
                if entry.monthlyBudget > 0 && entry.daysLeftInMonth > 0 && !entry.overBudget {
                    Divider()
                    
                    HStack {
                        Text("Daily Budget")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text(entry.dailyBudgetRecommendation, format: .currency(code: currencyCode))
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding(12)
    }
    
    // MARK: - Large Widget
    var largeWidget: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Top section with month summary
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Month to Date")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text(entry.totalSpent, format: .currency(code: currencyCode))
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(entry.overBudget ? .red : .primary)
                }
                
                Spacer()
                
                if entry.monthlyBudget > 0 {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Monthly Budget")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Text(entry.monthlyBudget, format: .currency(code: currencyCode))
                            .font(.title2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // Budget progress section
            if entry.monthlyBudget > 0 {
                VStack(alignment: .leading, spacing: 4) {
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color(.systemGray5))
                                .frame(height: 12)
                            
                            RoundedRectangle(cornerRadius: 6)
                                .fill(entry.overBudget ? Color.red : Color.blue)
                                .frame(width: min(CGFloat(entry.budgetProgress) * geometry.size.width, geometry.size.width), height: 12)
                        }
                    }
                    .frame(height: 12)
                    
                    HStack {
                        if entry.overBudget {
                            Text("Over budget")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            Text(entry.totalSpent - entry.monthlyBudget, format: .currency(code: currencyCode))
                                .font(.headline)
                                .foregroundColor(.red)
                        } else {
                            Text("Remaining")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            Text(entry.budgetRemaining, format: .currency(code: currencyCode))
                                .font(.headline)
                                .foregroundColor(.blue)
                            
                            Text("(\(Int(entry.budgetProgress * 100))% used)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.leading, 4)
                        }
                        
                        Spacer()
                        
                        Text("\(entry.daysLeftInMonth) days left")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Divider()
            
            // Category breakdown section
            VStack(alignment: .leading, spacing: 10) {
                Text("Spending by Category")
                    .font(.headline)
                    .padding(.bottom, 2)
                
                if entry.spendingByCategory.isEmpty {
                    Text("No expenses recorded this month")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 4)
                } else {
                    // Calculate max value for proportional bars
                    let maxValue = entry.topCategories.first?.1 ?? 1
                    
                    ForEach(Array(entry.topCategories.prefix(5)), id: \.0) { category, amount in
                        HStack(spacing: 8) {
                            // Category icon and name
                            HStack(spacing: 6) {
                                ZStack {
                                    Circle()
                                        .fill(category.color)
                                        .frame(width: 24, height: 24)
                                    
                                    Image(systemName: categoryIcon(for: category))
                                        .font(.system(size: 12))
                                        .foregroundColor(.white)
                                }
                                
                                Text(category.displayName)
                                    .font(.subheadline)
                                    .lineLimit(1)
                            }
                            .frame(width: 120, alignment: .leading)
                            
                            // Bar visualization
                            GeometryReader { geometry in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color(.systemGray5))
                                        .frame(height: 8)
                                    
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(category.color.opacity(0.8))
                                        .frame(width: max(CGFloat(amount / maxValue) * geometry.size.width, 20), height: 8)
                                }
                            }
                            .frame(height: 8)
                            
                            // Amount and percentage
                            VStack(alignment: .trailing, spacing: 0) {
                                Text(amount, format: .currency(code: currencyCode))
                                    .font(.subheadline)
                                
                                if entry.totalSpent > 0 {
                                    Text("\(Int((amount / entry.totalSpent) * 100))%")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .frame(width: 80, alignment: .trailing)
                        }
                    }
                }
            }
            
            Spacer()
            
            // Bottom recommendation section
            if entry.monthlyBudget > 0 && entry.daysLeftInMonth > 0 {
                Divider()
                
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.overBudget ? "You're over budget" : "Daily Budget")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        if !entry.overBudget {
                            Text(entry.dailyBudgetRecommendation, format: .currency(code: currencyCode))
                                .font(.headline)
                                .foregroundColor(.blue)
                        }
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Month Ends")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        let calendar = Calendar.current
                        let now = Date()
                        if let endOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: calendar.startOfDay(for: now)))?.addingTimeInterval(60*60*24*31) {
                            let endDate = calendar.date(from: calendar.dateComponents([.year, .month], from: endOfMonth))?.addingTimeInterval(-1) ?? Date()
                            
                            Text(endDate, style: .date)
                                .font(.subheadline)
                        }
                    }
                }
            }
        }
        .padding(16)
    }
    
    // Helper function to get category icon
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

struct iExpenseWidgetExtension: Widget {
    let kind: String = "iExpenseWidgetExtension"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, provider: ExpenseQuickAddProvider()) { entry in
            iExpenseWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        .configurationDisplayName("iExpense Tracker")
        .description("Track your monthly spending, budget progress, and top categories at a glance.")
    }
}

// MARK: - Previews
#Preview(as: .systemSmall) {
    iExpenseWidgetExtension()
} timeline: {
    ExpenseEntry(
        date: .now,
        totalSpent: 780.50,
        spendingByCategory: [
            .food: 250.00,
            .shopping: 175.75,
            .transportation: 80.25,
            .entertainment: 120.50,
            .utilities: 154.00
        ],
        monthlyBudget: 1000.00
    )
}

#Preview(as: .systemMedium) {
    iExpenseWidgetExtension()
} timeline: {
    ExpenseEntry(
        date: .now,
        totalSpent: 780.50,
        spendingByCategory: [
            .food: 250.00,
            .shopping: 175.75,
            .transportation: 80.25,
            .entertainment: 120.50,
            .utilities: 154.00
        ],
        monthlyBudget: 1000.00
    )
}

#Preview(as: .systemLarge) {
    iExpenseWidgetExtension()
} timeline: {
    ExpenseEntry(
        date: .now,
        totalSpent: 780.50,
        spendingByCategory: [
            .food: 250.00,
            .shopping: 175.75,
            .transportation: 80.25,
            .entertainment: 120.50,
            .utilities: 154.00
        ],
        monthlyBudget: 1000.00
    )
}

