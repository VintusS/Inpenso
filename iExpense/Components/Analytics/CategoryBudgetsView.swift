//
//  CategoryBudgetsView.swift
//  iExpense
//

import SwiftUI

/// Budget tab card: spending against each category's monthly limit.
struct CategoryBudgetsView: View {
    @EnvironmentObject private var categoryStore: CategoryStore
    let limits: [String: Double]
    let spendingByCategory: [String: Double]
    let currencyCode: String
    let onSave: ([String: Double]) -> Void
    @State private var showingEditor = false

    private struct LimitRow {
        let category: FinanceCategory
        let spent: Double
        let limit: Double
    }

    private var rows: [LimitRow] {
        categoryStore.orderedCategoryIDs(for: Set(limits.keys)).compactMap { id in
            guard let limit = limits[id], limit > 0 else { return nil }
            return LimitRow(category: categoryStore.category(for: id), spent: spendingByCategory[id] ?? 0, limit: limit)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Category Limits")
                    .font(.headline)
                Spacer()
                Button(rows.isEmpty ? "Set Limits" : "Edit") {
                    showingEditor = true
                }
                .font(.subheadline)
            }

            if rows.isEmpty {
                Text("Set a monthly limit for categories like Eating Out or Shopping to see how close you are.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                ForEach(rows, id: \.category.id) { row in
                    limitRow(row.category, spent: row.spent, limit: row.limit)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
        )
        .sheet(isPresented: $showingEditor) {
            CategoryBudgetEditor(limits: limits, currencyCode: currencyCode, onSave: onSave)
        }
    }

    private func limitRow(_ category: FinanceCategory, spent: Double, limit: Double) -> some View {
        let progress = spent / limit
        let color: Color = progress < 0.75 ? .blue : (progress <= 1 ? .orange : .red)
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: category.iconName)
                    .font(.caption)
                    .foregroundStyle(category.color.badgeForeground)
                    .frame(width: 24, height: 24)
                    .background(category.color)
                    .cornerRadius(6)
                Text(category.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                Text(spent, format: .currency(code: currencyCode))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text("/ \(limit.formatted(.currency(code: currencyCode)))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            ProgressView(value: min(progress, 1))
                .tint(color)
            if spent > limit {
                Text("Over by \((spent - limit).formatted(.currency(code: currencyCode)))")
                    .font(.caption)
                    .foregroundColor(.red)
            } else {
                Text("\((limit - spent).formatted(.currency(code: currencyCode))) left")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

struct CategoryBudgetEditor: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @EnvironmentObject private var categoryStore: CategoryStore
    let currencyCode: String
    let onSave: ([String: Double]) -> Void
    /// Raw (ungrouped) text per category ID.
    @State private var texts: [String: String]

    init(limits: [String: Double], currencyCode: String, onSave: @escaping ([String: Double]) -> Void) {
        self.currencyCode = currencyCode
        self.onSave = onSave
        let input = AmountInput(fractionDigits: currencyFractionDigits(for: currencyCode), locale: .current)
        _texts = State(initialValue: limits.mapValues { input.bindingText(for: $0) })
    }

    private var input: AmountInput {
        AmountInput(fractionDigits: currencyFractionDigits(for: currencyCode), locale: locale)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ForEach(categoryStore.categoriesForPicker(kind: .expense)) { category in
                        HStack {
                            Label(category.displayName, systemImage: category.iconName)
                            AmountTextField(placeholder: "No limit", raw: binding(for: category.id), input: input)
                                .multilineTextAlignment(.trailing)
                                .frame(maxWidth: .infinity)
                        }
                    }
                } footer: {
                    Text("Limits apply every month. Leave a field empty for no limit.")
                }
            }
            .navigationTitle("Category Limits")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(texts.compactMapValues { input.value(of: $0) })
                        dismiss()
                    }
                }
            }
        }
    }

    private func binding(for id: String) -> Binding<String> {
        Binding(get: { texts[id] ?? "" }, set: { texts[id] = $0 })
    }
}
