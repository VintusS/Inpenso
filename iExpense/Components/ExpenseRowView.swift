//
//  ExpenseRowView.swift
//  iExpense
//

import SwiftUI

struct ExpenseRowView: View {
    @EnvironmentObject private var categoryStore: CategoryStore

    let expense: Expense
    let currencyCode: String
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 6))
            : AnyLayout(HStackLayout(spacing: 12))

        layout {
            VStack(alignment: .leading, spacing: 4) {
                Text(expense.title)
                    .font(.headline)

                Label(category.displayName, systemImage: category.iconName)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(expense.date, format: .dateTime.weekday(.abbreviated).day().month(.abbreviated).year())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(amountText)
                .font(.system(.headline, design: .rounded).bold())
                .foregroundStyle(expense.type.amountColor)
        }
        .padding(.vertical, 6)
    }

    private var category: FinanceCategory {
        categoryStore.category(for: expense)
    }

    private var amountText: String {
        let formatted = expense.price.formatted(.currency(code: currencyCode))
        return expense.type.isInflow ? "+\(formatted)" : formatted
    }

}

struct ExpenseRowContent: View {
    let expense: Expense
    let currencyCode: String
    let onEdit: () -> Void
    /// Nil for rows that can't be deleted on their own, such as transfer fees.
    let onDelete: (() -> Void)?

    private var editLabel: String { onDelete == nil ? "Edit Transfer" : "Edit" }

    var body: some View {
        Button(action: onEdit) {
            ExpenseRowView(expense: expense, currencyCode: currencyCode)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(action: onEdit) {
                Label(editLabel, systemImage: "pencil")
            }

            if let onDelete {
                Button(role: .destructive, action: onDelete) {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
        .swipeActions(edge: .leading) {
            if let onDelete {
                Button(role: .destructive, action: onDelete) {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
        .swipeActions(edge: .trailing) {
            Button(action: onEdit) {
                Label(editLabel, systemImage: "pencil")
            }
            .tint(.blue)
        }
    }
}
