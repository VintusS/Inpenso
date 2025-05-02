// iExpenseWidgetExtension.swift
// iExpenseWidgetExtension

import WidgetKit
import SwiftUI
import AppIntents
import Foundation

// Global app group ID for consistency - must match StorageService.appGroupID
let appGroupID = "group.com.vintuss.iexpense"

// Diagnostic function to test read/write in widget
func testWidgetSharedDefaults() {
    print("===== WIDGET SHARED DEFAULTS DIAGNOSTIC TEST =====")
    
    let testValue = "USD_TEST_\(Int(Date().timeIntervalSince1970))"
    let testKey = "widgetTest"
    
    // Try to write a value
    if let sharedDefaults = UserDefaults(suiteName: appGroupID) {
        print("Widget can access shared defaults with ID: \(appGroupID)")
        sharedDefaults.set(testValue, forKey: testKey)
        sharedDefaults.synchronize()
        
        // Try to read it back
        let readValue = sharedDefaults.string(forKey: testKey)
        print("Widget test write+read: expected=\(testValue), actual=\(readValue ?? "nil")")
        
        // Try to read currency
        let currency = sharedDefaults.string(forKey: "selectedCurrency")
        print("Widget reading currency: \(currency ?? "nil")")
    } else {
        print("CRITICAL ERROR: Widget cannot access shared defaults!")
    }
    
    print("=================================================")
}

// Global function to get currency code from shared UserDefaults
func getAppCurrency() -> String {
    // Run diagnostics
    testWidgetSharedDefaults()
    
    // First try to get from shared defaults with explicit initialization
    let sharedDefaults = UserDefaults(suiteName: appGroupID)
    print("Widget using app group ID: \(appGroupID)")
    
    // Log current process and bundle information for debugging
    let processInfo = ProcessInfo.processInfo
    print("Widget process name: \(processInfo.processName)")
    print("Widget bundle ID: \(Bundle.main.bundleIdentifier ?? "unknown")")
    
    var currency: String? = nil
    
    if let sharedDefaults = sharedDefaults {
        // Force a synchronize before reading
        sharedDefaults.synchronize()
        
        // List all available keys for debugging
        let allKeys = sharedDefaults.dictionaryRepresentation().keys
        print("Available keys in shared defaults: \(allKeys)")
        
        // Try to read the currency directly
        currency = sharedDefaults.string(forKey: "selectedCurrency")
        print("Widget reading currency from shared defaults: \(currency ?? "nil")")
        
        // If found, return it
        if let currency = currency {
            return currency
        }
    } else {
        print("ERROR: Could not access shared UserDefaults with app group ID: \(appGroupID)")
    }
    
    // If we got here, try standard UserDefaults
    let standardDefaults = UserDefaults.standard
    standardDefaults.synchronize()
    let standardCurrency = standardDefaults.string(forKey: "selectedCurrency")
    print("Widget fallback to standard defaults: \(standardCurrency ?? "nil")")
    
    // If all else fails, return USD
    return standardCurrency ?? "USD"
}

struct ExpenseEntry: TimelineEntry {
    let date: Date
    let totalSpent: Double
    let spendingByCategory: [Category: Double]
}

struct ExpenseQuickAddProvider: AppIntentTimelineProvider {
    typealias Intent = QuickAddConfigurationIntent
    
    // Use the shared app group
    private let sharedDefaults = UserDefaults(suiteName: appGroupID)

    func placeholder(in context: Context) -> ExpenseEntry {
        ExpenseEntry(date: Date(), totalSpent: 0, spendingByCategory: [:])
    }

    func snapshot(for configuration: QuickAddConfigurationIntent, in context: Context) async -> ExpenseEntry {
        await loadEntry()
    }

    func timeline(for configuration: QuickAddConfigurationIntent, in context: Context) async -> Timeline<ExpenseEntry> {
        let entry = await loadEntry()
        let timeline = Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(3600))) // refresh every 1h
        return timeline
    }

    private func loadEntry() async -> ExpenseEntry {
        let expenses = StorageService.loadExpenses()

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

        return ExpenseEntry(date: Date(), totalSpent: total, spendingByCategory: categoryTotals)
    }
}

struct iExpenseWidgetEntryView: View {
    var entry: ExpenseEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Total Spent")
                .font(.headline)
                .foregroundColor(.secondary)

            Text(entry.totalSpent, format: .currency(code: getAppCurrency()))
                .font(.title2)
                .fontWeight(.bold)

            if !entry.spendingByCategory.isEmpty {
                Divider()
                ForEach(entry.spendingByCategory.sorted(by: { $0.value > $1.value }).prefix(2), id: \.key) { category, amount in
                    HStack {
                        Text(category.displayName)
                            .font(.caption)
                        Spacer()
                        Text(amount, format: .currency(code: getAppCurrency()))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding()
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
        .configurationDisplayName("iExpense")
        .description("Track your current month's spending at a glance.")
    }
}

#Preview(as: .systemSmall) {
    iExpenseWidgetExtension()
} timeline: {
    ExpenseEntry(
        date: .now,
        totalSpent: 125.75,
        spendingByCategory: [
            .food: 50.00,
            .shopping: 75.75
        ]
    )
}

