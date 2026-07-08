import Foundation
import UserNotifications

enum Notifier {
    /// System notification on danger activation. UNUserNotificationCenter
    /// requires a real bundle - silently skip under bare `swift run`.
    static func dangerActivated(group: String, profile: String) {
        guard Bundle.main.bundleIdentifier != nil else { return }
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }
            let content = UNMutableNotificationContent()
            content.title = "⚠ \(profile) is now active for \(group)"
            content.body = "Every NEW shell/process targets \(profile). Existing shells keep old values. Switch back when done."
            center.add(
                UNNotificationRequest(
                    identifier: UUID().uuidString,
                    content: content,
                    trigger: nil
                )
            )
        }
    }
}
