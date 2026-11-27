//
//  CreditDueReminder.swift
//  iExpense
//

import Foundation
import UserNotifications

/// Local notifications for credit card and paylater due dates: 3 days before and on the day, at 09:00.
/// Rebuilt from the current due list whenever wallet data refreshes, so a payment cancels its reminders.
@MainActor
enum CreditDueReminder {
    private static let prefix = "credit-due-"
    private static let remindHour = 9
    private static var lastSignature: String?

    /// One reminder per wallet per due date; a card bill and an instalment due the same day are summed.
    private struct Due {
        let key: String
        let walletName: String
        let amount: Double
        let dueDate: Date
    }

    static func reschedule(dues: [DueItem], walletName: (UUID) -> String?) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var grouped: [String: Due] = [:]
        for item in dues where calendar.startOfDay(for: item.dueDate) >= today {
            let day = calendar.startOfDay(for: item.dueDate)
            let key = "\(item.walletID.uuidString)-\(Int(day.timeIntervalSince1970))"
            let name = walletName(item.walletID) ?? item.title
            let previous = grouped[key]?.amount ?? 0
            grouped[key] = Due(key: key, walletName: name, amount: previous + item.amount, dueDate: day)
        }
        let items = grouped.values.sorted { $0.key < $1.key }
        let signature = items.map { "\($0.key):\(Int($0.amount.rounded()))" }.joined(separator: "|")
        guard signature != lastSignature else { return }
        lastSignature = signature

        Task {
            let center = UNUserNotificationCenter.current()
            let pending = await center.pendingNotificationRequests()
            center.removePendingNotificationRequests(withIdentifiers: pending.map(\.identifier).filter { $0.hasPrefix(prefix) })
            guard !items.isEmpty else { return }

            let settings = await center.notificationSettings()
            if settings.authorizationStatus == .notDetermined {
                guard (try? await center.requestAuthorization(options: [.alert, .sound])) == true else { return }
            } else if settings.authorizationStatus != .authorized && settings.authorizationStatus != .provisional {
                return
            }

            let currency = UserDefaults.standard.string(forKey: "selectedCurrency") ?? "IDR"
            for due in items {
                let amount = due.amount.formatted(.currency(code: currency).precision(.fractionLength(0)))
                let dateText = due.dueDate.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
                for (suffix, daysBefore) in [("3d", 3), ("0d", 0)] {
                    guard let day = calendar.date(byAdding: .day, value: -daysBefore, to: due.dueDate),
                          let fire = calendar.date(bySettingHour: remindHour, minute: 0, second: 0, of: day),
                          fire > Date()
                    else { continue }
                    let content = UNMutableNotificationContent()
                    content.title = daysBefore == 0 ? "\(due.walletName) payment due today" : "\(due.walletName) payment due in 3 days"
                    content.body = daysBefore == 0
                        ? "\(amount) is due today. Pay it, then record it with Pay in Inpenso."
                        : "\(amount) is due \(dateText)."
                    content.sound = .default
                    let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fire)
                    let request = UNNotificationRequest(
                        identifier: "\(prefix)\(due.key)-\(suffix)",
                        content: content,
                        trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
                    )
                    try? await center.add(request)
                }
            }
        }
    }
}
