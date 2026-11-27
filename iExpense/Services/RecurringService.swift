//
//  RecurringService.swift
//  iExpense
//

import Foundation

enum RecurringService {
    private static let rulesKey = "recurringRules"
    /// How far back missed occurrences are offered for review.
    static let maxMonthsBack = 12

    private static var defaults: UserDefaults? {
        StorageService.sharedDefaults
    }

    // MARK: - Rules storage

    static func loadRules() -> [RecurringRule] {
        guard let data = defaults?.data(forKey: rulesKey),
              let rules = try? JSONDecoder().decode([RecurringRule].self, from: data) else {
            return []
        }
        return rules
    }

    static func saveRules(_ rules: [RecurringRule]) {
        guard let data = try? JSONEncoder().encode(rules) else { return }
        defaults?.set(data, forKey: rulesKey)
    }

    // MARK: - Due occurrences

    static func monthKey(for date: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.year, .month], from: date)
        return String(format: "%04d-%02d", parts.year ?? 0, parts.month ?? 0)
    }

    /// Occurrences whose due date has passed and that are neither posted nor skipped,
    /// oldest first. Covers at most `maxMonthsBack` months before `now`.
    static func dueOccurrences(
        rules: [RecurringRule],
        postedIDs: Set<UUID>,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [RecurringOccurrence] {
        guard let earliest = calendar.date(byAdding: .month, value: -maxMonthsBack, to: now) else { return [] }
        var result: [RecurringOccurrence] = []

        for rule in rules where rule.isActive {
            let first = max(rule.startDate, earliest)
            guard var month = calendar.date(from: calendar.dateComponents([.year, .month], from: first)) else { continue }
            while month <= now {
                let key = monthKey(for: month, calendar: calendar)
                if let due = rule.dueDate(inMonthOf: month, calendar: calendar),
                   due <= now,
                   calendar.startOfDay(for: due) >= calendar.startOfDay(for: rule.startDate),
                   !rule.skippedMonths.contains(key) {
                    let occurrence = RecurringOccurrence(rule: rule, dueDate: due, monthKey: key)
                    if !postedIDs.contains(occurrence.id) {
                        result.append(occurrence)
                    }
                }
                guard let next = calendar.date(byAdding: .month, value: 1, to: month) else { break }
                month = next
            }
        }
        return result.sorted { $0.dueDate < $1.dueDate }
    }

    // MARK: - Actions

    /// Adds the occurrences as transactions. Already-posted ones are ignored.
    /// A rule whose wallet was archived or deleted posts to the default wallet instead.
    static func post(_ occurrences: [RecurringOccurrence]) throws {
        try StorageService.updateLedger { ledger in
            let existing = Set(ledger.transactions.map(\.id))
            let activeWallets = Set(ledger.wallets.filter { !$0.isArchived }.map(\.id))
            for occurrence in occurrences where !existing.contains(occurrence.id) {
                let rule = occurrence.rule
                let walletID = rule.walletID.flatMap { activeWallets.contains($0) ? $0 : nil } ?? ledger.defaultWalletID
                ledger.transactions.append(Expense(
                    id: occurrence.id,
                    title: rule.title,
                    price: rule.amount,
                    date: occurrence.dueDate,
                    category: Category.category(from: rule.categoryID) ?? .others,
                    type: rule.type,
                    categoryID: rule.categoryID,
                    notes: rule.notes,
                    walletID: walletID
                ))
            }
        }
        NotificationCenter.default.post(name: .inpensoDataDidChange, object: nil)
    }

    static func skip(_ occurrence: RecurringOccurrence) {
        var rules = loadRules()
        guard let index = rules.firstIndex(where: { $0.id == occurrence.rule.id }) else { return }
        rules[index].skippedMonths.insert(occurrence.monthKey)
        saveRules(rules)
    }
}
