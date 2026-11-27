//
//  ProvisioningInfo.swift
//  iExpense
//

import Foundation
import UserNotifications

/// Reads the signing profile embedded in a development build.
/// Free Apple ID builds stop launching when this profile expires (7 days after install).
enum ProvisioningInfo {
    /// nil for App Store / TestFlight builds and the simulator, which ship without `embedded.mobileprovision`.
    static let expirationDate: Date? = {
        guard let url = Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision"),
              let data = try? Data(contentsOf: url),
              let raw = String(data: data, encoding: .isoLatin1),
              let start = raw.range(of: "<?xml"),
              let end = raw.range(of: "</plist>"),
              start.lowerBound < end.upperBound,
              let plistData = String(raw[start.lowerBound..<end.upperBound]).data(using: .isoLatin1),
              let plist = try? PropertyListSerialization.propertyList(from: plistData, format: nil) as? [String: Any]
        else { return nil }
        return plist["ExpirationDate"] as? Date
    }()
}

/// Local notifications before a development build expires: one day ahead and two hours ahead.
/// Rescheduled on every launch, so a reinstall with a new profile moves them.
enum ReinstallReminder {
    private struct Reminder {
        let id: String
        let lead: TimeInterval
        let body: String
    }

    private static let identifiers = ["reinstall-reminder-1d", "reinstall-reminder-2h"]

    static func schedule() async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
        guard var expiry = ProvisioningInfo.expirationDate, expiry > Date() else { return }
        #if DEBUG
        // `-testReinstallReminder`: pretend the build expires in 2 h 0 m 30 s, so the "2 hours" reminder
        // fires 30 s after launch (the 1-day one is skipped as already past).
        if ProcessInfo.processInfo.arguments.contains("-testReinstallReminder") {
            expiry = Date().addingTimeInterval(7_230)
        }
        #endif
        guard (try? await center.requestAuthorization(options: [.alert, .sound])) == true else { return }

        let time = expiry.formatted(.dateTime.weekday(.wide).hour().minute())
        let clock = expiry.formatted(date: .omitted, time: .shortened)
        let reminders = [
            Reminder(id: identifiers[0], lead: 86_400,
                     body: "Inpenso stops opening tomorrow, \(time). Reinstall it from Xcode; your data stays."),
            Reminder(id: identifiers[1], lead: 7_200,
                     body: "Inpenso stops opening at \(clock). Reinstall it from Xcode now."),
        ]
        for reminder in reminders {
            let fireDate = expiry.addingTimeInterval(-reminder.lead)
            guard fireDate > Date() else { continue }
            let content = UNMutableNotificationContent()
            content.title = "Reinstall Inpenso"
            content.body = reminder.body
            content.sound = .default
            let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: fireDate)
            let request = UNNotificationRequest(
                identifier: reminder.id, content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            )
            try? await center.add(request)
        }
    }

    #if DEBUG
    /// `-dumpNotifications`: writes permission and pending requests to Documents/notifications.txt.
    static func dumpState() async {
        guard ProcessInfo.processInfo.arguments.contains("-dumpNotifications") else { return }
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        let pending = await center.pendingNotificationRequests()
        var lines = [
            "authorization: \(settings.authorizationStatus.rawValue) (0 notDetermined, 1 denied, 2 authorized, 3 provisional)",
            "alert: \(settings.alertSetting.rawValue), lockScreen: \(settings.lockScreenSetting.rawValue), "
                + "notificationCenter: \(settings.notificationCenterSetting.rawValue) (2 = enabled)",
            "expiry: \(String(describing: ProvisioningInfo.expirationDate))",
            "now: \(Date())",
        ]
        for request in pending {
            let next = (request.trigger as? UNCalendarNotificationTrigger)?.nextTriggerDate()
            lines.append("pending \(request.identifier) next=\(String(describing: next))")
        }
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("notifications.txt")
        try? lines.joined(separator: "\n").write(to: url, atomically: true, encoding: .utf8)
    }
    #endif
}

/// Shows Inpenso's own notifications as banners even while the app is open (iOS hides them by default).
final class ForegroundNotificationPresenter: NSObject, UNUserNotificationCenterDelegate {
    static let shared = ForegroundNotificationPresenter()

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification)
        async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }
}
