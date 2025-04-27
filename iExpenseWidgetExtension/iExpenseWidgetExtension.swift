// iExpenseWidgetExtension.swift
// iExpenseWidgetExtension

import WidgetKit
import SwiftUI
import AppIntents

struct ExpenseEntry: TimelineEntry {
    let date: Date
}

struct ExpenseQuickAddProvider: AppIntentTimelineProvider {
    typealias Intent = QuickAddConfigurationIntent

    func placeholder(in context: Context) -> ExpenseEntry {
        ExpenseEntry(date: Date())
    }

    func snapshot(for configuration: QuickAddConfigurationIntent, in context: Context) async -> ExpenseEntry {
        ExpenseEntry(date: Date())
    }

    func timeline(for configuration: QuickAddConfigurationIntent, in context: Context) async -> Timeline<ExpenseEntry> {
        let entry = ExpenseEntry(date: Date())
        return Timeline(entries: [entry], policy: .never)
    }
}


struct iExpenseWidgetEntryView: View {
    var entry: ExpenseEntry

    var body: some View {
        VStack(spacing: 10) {
            Button(intent: AddQuickExpenseIntent(title: "Coffee", amount: 5.0, category: "food")) {
                Label("Add Coffee", systemImage: "cup.and.saucer.fill")
            }
            .buttonStyle(.borderedProminent)

            Button(intent: AddQuickExpenseIntent(title: "Bus Ticket", amount: 2.5, category: "transportation")) {
                Label("Add Bus", systemImage: "bus.fill")
            }
            .buttonStyle(.borderedProminent)

            Button(intent: AddQuickExpenseIntent(title: "Groceries", amount: 20.0, category: "shopping")) {
                Label("Add Groceries", systemImage: "cart.fill")
            }
            .buttonStyle(.borderedProminent)
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
    ExpenseEntry(date: .now)
}
