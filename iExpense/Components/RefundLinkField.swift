//
//  RefundLinkField.swift
//  iExpense
//

import SwiftUI

/// Optional link from a refund to the purchase it pays back.
struct RefundLinkField: View {
    @Binding var selection: UUID?
    let purchases: [Expense]
    let currencyCode: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Refund for")
                .font(.subheadline)
                .foregroundColor(.secondary)
            HStack {
                Picker("Refund for", selection: $selection) {
                    Text("Not linked").tag(UUID?.none)
                    ForEach(purchases) { purchase in
                        Text(label(for: purchase)).tag(UUID?.some(purchase.id))
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                Spacer()
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
            .background(Color(.tertiarySystemBackground))
            .cornerRadius(10)
            Text(selection == nil
                 ? "Lowers spending in the month the money arrives."
                 : "Lowers spending in the purchase's month, even if the money arrives later.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private func label(for purchase: Expense) -> String {
        let date = purchase.date.formatted(.dateTime.day().month(.abbreviated))
        return "\(purchase.title) · \(date) · \(purchase.price.formatted(.currency(code: currencyCode)))"
    }

    /// Purchases a refund dated `date` can pay back: from 90 days before, newest first.
    /// Keeps `linkedID` in the list even when it falls outside that window.
    static func candidates(in transactions: [Expense], refundDate date: Date, linkedID: UUID?) -> [Expense] {
        let calendar = Calendar.current
        let end = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: date)) ?? date
        let start = calendar.date(byAdding: .day, value: -90, to: end) ?? date
        let inWindow = transactions.filter { transaction in
            transaction.type == .expense && transaction.date >= start && transaction.date < end
        }
        let newestFirst: [Expense] = inWindow.sorted { $0.date > $1.date }
        var purchases = Array(newestFirst.prefix(60))
        if let linkedID, !purchases.contains(where: { $0.id == linkedID }),
           let linked = transactions.first(where: { $0.id == linkedID }) {
            purchases.append(linked)
        }
        return purchases
    }
}
