// iExpenseWidgetExtension.swift
// iExpenseWidgetExtension

import WidgetKit
import SwiftUI
import AppIntents
import Foundation

struct ExpenseEntry: TimelineEntry {
    let date: Date
    let totalSpent: Double
    let spendingByCategory: [Category: Double]
}

struct ExpenseQuickAddProvider: AppIntentTimelineProvider {
    typealias Intent = QuickAddConfigurationIntent

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

            Text(entry.totalSpent, format: .currency(code: UserDefaults.standard.string(forKey: "selectedCurrency") ?? "USD"))
                .font(.title2)
                .fontWeight(.bold)

            if !entry.spendingByCategory.isEmpty {
                Divider()
                ForEach(entry.spendingByCategory.sorted(by: { $0.value > $1.value }).prefix(2), id: \.key) { category, amount in
                    HStack {
                        Text(category.displayName)
                            .font(.caption)
                        Spacer()
                        Text(amount, format: .currency(code: UserDefaults.standard.string(forKey: "selectedCurrency") ?? "USD"))
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

