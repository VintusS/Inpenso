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
    
    // MARK: - Small Widget (2x2)
    var smallWidget: some View {
        ZStack {
            VStack(alignment: .center, spacing: 4) {
                // "Monthly Spend" title with icon
                HStack(spacing: 4) {
                    Image(systemName: "dollarsign.circle.fill")
                        .foregroundColor(entry.overBudget ? .red : .blue)
                        .font(.system(size: 14))
                    
                    Text("MONTHLY SPEND")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.secondary)
                        .kerning(0.5)
                }
                .padding(.top, 4)
                
                Spacer()
                
                // Amount in large, attractive font
                Text(entry.totalSpent, format: .currency(code: currencyCode))
                    .font(.system(.title2, design: .rounded))
                    .fontWeight(.bold)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .foregroundColor(entry.overBudget ? .red : .primary)
                    .shadow(color: Color.black.opacity(0.05), radius: 1, x: 0, y: 1)
                    
                // Budget indicator if budget exists
                    if entry.monthlyBudget > 0 {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(entry.overBudget ? .red : .green)
                            .frame(width: 6, height: 6)
                        
                        Text(entry.overBudget ? "Over Budget" : "\(Int(entry.budgetProgress * 100))% of Budget")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(entry.overBudget ? .red : .green)
                    }
                    .padding(.bottom, 2)
                    } else {
                    Text("This Month")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .padding(.bottom, 2)
                }
                    
                    Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
        }
    }
    
    // MARK: - Medium Widget
    var mediumWidget: some View {
        HStack(spacing: 16) {
            // Left section - Monthly spending amount
            VStack(alignment: .leading, spacing: 4) {
                        Text(entry.totalSpent, format: .currency(code: currencyCode))
                    .font(.system(.title, design: .rounded))
                            .fontWeight(.bold)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                            .foregroundColor(entry.overBudget ? .red : .primary)
                
                Text("spent this month")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // Right section - Budget circle if available
            if entry.monthlyBudget > 0 {
                ZStack {
                    // Background circle
                                Circle()
                        .stroke(Color(.systemGray5), lineWidth: 8)
                        .frame(width: 80, height: 80)
                                
                    // Progress circle
                    Circle()
                        .trim(from: 0, to: entry.budgetProgress)
                        .stroke(
                            entry.overBudget ? Color.red : Color.green,
                            style: StrokeStyle(lineWidth: 8, lineCap: .round)
                        )
                        .frame(width: 80, height: 80)
                        .rotationEffect(.degrees(-90))
                    
                    // Percentage text
                    VStack(spacing: 0) {
                        Text("\(Int(entry.budgetProgress * 100))%")
                            .font(.system(.body, design: .rounded))
                            .fontWeight(.bold)
                            .foregroundColor(entry.overBudget ? .red : .green)
                        
                        Text("of budget")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                }
            }
                .frame(width: 100, height: 100)
            }
        }
        .padding(16)
    }
    
    // MARK: - Large Widget
    var largeWidget: some View {
        VStack {
            // Top - Monthly spending
                    Text(entry.totalSpent, format: .currency(code: currencyCode))
                .font(.system(.largeTitle, design: .rounded))
                        .fontWeight(.bold)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                        .foregroundColor(entry.overBudget ? .red : .primary)
            
            Text("spent this month")
                .font(.headline)
                .foregroundColor(.secondary)
                
            // Budget visualization if available
            if entry.monthlyBudget > 0 {
                Spacer()
                
                ZStack {
                    // Background circle
                    Circle()
                        .stroke(Color(.systemGray5), lineWidth: 15)
                        .frame(width: 180, height: 180)
                    
                    // Progress circle
                    Circle()
                        .trim(from: 0, to: entry.budgetProgress)
                        .stroke(
                            entry.overBudget ? Color.red : Color.green,
                            style: StrokeStyle(lineWidth: 15, lineCap: .round)
                        )
                        .frame(width: 180, height: 180)
                        .rotationEffect(.degrees(-90))
                    
                    // Inner information
                    VStack(spacing: 4) {
                        Text(entry.overBudget ? "OVER BUDGET" : "BUDGET")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                        
                        if entry.overBudget {
                            Text(entry.totalSpent - entry.monthlyBudget, format: .currency(code: currencyCode))
                                .font(.system(.title3, design: .rounded))
                                .fontWeight(.bold)
                                .foregroundColor(.red)
                        } else {
                            Text(entry.budgetRemaining, format: .currency(code: currencyCode))
                                .font(.system(.title3, design: .rounded))
                                .fontWeight(.bold)
                                .foregroundColor(.green)
                        }
                            
                        Text("\(Int(entry.budgetProgress * 100))% used")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Text("\(entry.daysLeftInMonth) days left in the month")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                Spacer()
                
                // If no budget, show a message
                VStack {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 50))
                        .foregroundColor(.secondary)
                        .padding(.bottom, 10)
                    
                    Text("No budget set for this month")
                        .font(.title3)
                                        .foregroundColor(.secondary)
                                }
                .padding()
                    
                    Spacer()
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
                .containerBackground(.widgetBackground, for: .widget)
        }
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        .configurationDisplayName("iExpense Tracker")
        .description("Track your monthly spending, budget progress, and top categories at a glance.")
    }
}

// MARK: - Widget Background Extension
extension ShapeStyle where Self == Color {
    static var widgetBackground: Color {
        Color(.systemBackground)
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

