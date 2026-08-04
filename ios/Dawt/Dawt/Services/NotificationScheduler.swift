import Foundation
import UserNotifications

enum NotificationScheduler {
    static func reschedule(profile: UserProfile, prediction: CyclePrediction) {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        guard profile.remindersEnabled else { return }

        if let next = prediction.nextPeriodStart {
            schedule(
                id: "period-upcoming",
                title: "dawt reminder",
                body: "Your period may be coming up soon.",
                date: Calendar.current.date(byAdding: .day, value: -2, to: next) ?? next
            )
        }

        if let fertileStart = prediction.fertileWindow?.lowerBound {
            schedule(
                id: "fertile-start",
                title: "dawt reminder",
                body: "An estimated fertile window is starting.",
                date: fertileStart
            )
        }

        var components = DateComponents()
        components.hour = 9
        components.minute = 0
        let content = UNMutableNotificationContent()
        content.title = "Dawt"
        content.body = "Quick check-in: log how you feel today."
        content.sound = .default
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        center.add(UNNotificationRequest(identifier: "daily-log", content: content, trigger: trigger))
    }

    private static func schedule(id: String, title: String, body: String, date: Date) {
        guard date > Date() else { return }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }
}
