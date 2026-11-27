//
//  RecurringDueCard.swift
//  iExpense
//

import SwiftUI

/// Home card: recurring items that are due, to add or skip, plus a link to manage rules.
struct RecurringDueCard: View {
    @ObservedObject var recurringViewModel: RecurringViewModel
    @EnvironmentObject private var settingsViewModel: SettingsViewModel
    @EnvironmentObject private var categoryStore: CategoryStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recurring")
                    .font(.headline)
                Spacer()
                NavigationLink {
                    RecurringRulesView(recurringViewModel: recurringViewModel)
                } label: {
                    Text(recurringViewModel.rules.isEmpty ? "Set Up" : "Manage")
                        .font(.caption)
                }
            }

            let due = recurringViewModel.dueOccurrences
            if due.isEmpty {
                Text(recurringViewModel.rules.isEmpty
                     ? "Add salary, rent or subscriptions once and confirm them each month."
                     : "Nothing due. You're up to date.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                ForEach(due.prefix(5)) { occurrence in
                    row(for: occurrence)
                    if occurrence.id != due.prefix(5).last?.id {
                        Divider().padding(.leading, 40)
                    }
                }
                if due.count > 5 {
                    Text("+\(due.count - 5) more")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                if due.count > 1 {
                    Button {
                        HapticFeedback.success()
                        recurringViewModel.post(due)
                    } label: {
                        Text("Add All (\(due.count))")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.secondarySystemBackground))
                .shadow(color: Color(.label).opacity(0.05), radius: 10, x: 0, y: 5)
        )
        .alert("Recurring", isPresented: Binding(
            get: { recurringViewModel.postError != nil },
            set: { if !$0 { recurringViewModel.postError = nil } }
        )) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(recurringViewModel.postError ?? "")
        }
    }

    private func row(for occurrence: RecurringOccurrence) -> some View {
        let rule = occurrence.rule
        let category = categoryStore.category(for: rule.categoryID)
        return HStack(spacing: 12) {
            Image(systemName: category.iconName)
                .font(.subheadline)
                .foregroundStyle(category.color.badgeForeground)
                .frame(width: 28, height: 28)
                .background(category.color)
                .cornerRadius(6)

            VStack(alignment: .leading, spacing: 2) {
                Text(rule.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                HStack(spacing: 4) {
                    Text(occurrence.dueDate, style: .date)
                    Text("·")
                    Text(rule.amount, format: .currency(code: settingsViewModel.selectedCurrency))
                        .foregroundColor(rule.type.amountColor)
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }

            Spacer()

            Button("Skip") {
                recurringViewModel.skip(occurrence)
            }
            .font(.caption)
            .buttonStyle(.borderless)
            .foregroundColor(.secondary)

            Button("Add") {
                HapticFeedback.success()
                recurringViewModel.post([occurrence])
            }
            .font(.caption.weight(.semibold))
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
    }
}
