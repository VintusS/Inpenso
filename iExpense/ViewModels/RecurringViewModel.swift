//
//  RecurringViewModel.swift
//  iExpense
//

import Foundation

@MainActor
final class RecurringViewModel: ObservableObject {
    @Published private(set) var rules: [RecurringRule] = []
    @Published private(set) var dueOccurrences: [RecurringOccurrence] = []

    init() {
        refresh()
    }

    func refresh() {
        rules = RecurringService.loadRules()
        let postedIDs = Set(StorageService.loadExpenses().map(\.id))
        dueOccurrences = RecurringService.dueOccurrences(rules: rules, postedIDs: postedIDs)
    }

    func save(_ rule: RecurringRule) {
        var all = RecurringService.loadRules()
        if let index = all.firstIndex(where: { $0.id == rule.id }) {
            all[index] = rule
        } else {
            all.append(rule)
        }
        RecurringService.saveRules(all)
        refresh()
    }

    func delete(_ rule: RecurringRule) {
        RecurringService.saveRules(RecurringService.loadRules().filter { $0.id != rule.id })
        refresh()
    }

    func post(_ occurrences: [RecurringOccurrence]) {
        RecurringService.post(occurrences)
        refresh()
    }

    func skip(_ occurrence: RecurringOccurrence) {
        RecurringService.skip(occurrence)
        refresh()
    }
}
