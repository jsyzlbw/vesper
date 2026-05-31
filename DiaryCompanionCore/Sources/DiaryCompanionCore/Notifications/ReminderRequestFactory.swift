import Foundation
import UserNotifications

public struct ReminderRequestFactory: Sendable {
    private let calendar: Calendar

    public init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    public func makeRequest(
        id: String,
        title: String,
        body: String,
        fireDate: Date
    ) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let components = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: fireDate
        )
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: components,
            repeats: false
        )
        return UNNotificationRequest(
            identifier: id,
            content: content,
            trigger: trigger
        )
    }
}
