//
//  RecurringRule.swift
//  iExpense
//

import CryptoKit
import Foundation

/// A monthly repeating income or expense, e.g. salary on the 25th or rent on the 1st.
struct RecurringRule: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var title: String
    var amount: Double
    var type: TransactionType
    var categoryID: String
    /// 1...31. In shorter months the occurrence falls on the month's last day.
    var dayOfMonth: Int
    /// No occurrences are due before this date.
    var startDate: Date
    var isActive: Bool = true
    var notes: String?
    /// Wallet each occurrence posts to; nil = the default wallet at posting time.
    var walletID: UUID?
    /// Months ("yyyy-MM") the user chose to skip.
    var skippedMonths: Set<String> = []

    /// The due date of this rule in the month containing `date`.
    func dueDate(inMonthOf date: Date, calendar: Calendar = .current) -> Date? {
        guard let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: date)),
              let dayRange = calendar.range(of: .day, in: .month, for: monthStart) else {
            return nil
        }
        let day = min(max(dayOfMonth, 1), dayRange.count)
        return calendar.date(byAdding: .day, value: day - 1, to: monthStart)
    }
}

/// One due posting of a rule in a given month.
struct RecurringOccurrence: Identifiable, Equatable {
    let rule: RecurringRule
    let dueDate: Date
    /// "yyyy-MM"
    let monthKey: String

    var id: UUID { RecurringOccurrence.transactionID(ruleID: rule.id, monthKey: monthKey) }

    /// Stable transaction ID for a rule's month, so the same occurrence is never posted twice,
    /// even if the app, a widget and another device race to post it.
    static func transactionID(ruleID: UUID, monthKey: String) -> UUID {
        let digest = SHA256.hash(data: Data("\(ruleID.uuidString)|\(monthKey)".utf8))
        var bytes = Array(digest.prefix(16))
        bytes[6] = (bytes[6] & 0x0F) | 0x50 // version 5 style
        bytes[8] = (bytes[8] & 0x3F) | 0x80 // RFC 4122 variant
        return UUID(uuid: (bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7],
                           bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]))
    }
}
