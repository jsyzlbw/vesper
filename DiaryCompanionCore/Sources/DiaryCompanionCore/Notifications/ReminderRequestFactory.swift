import Foundation
import UserNotifications

public enum ReminderRequestFactoryError: Error, Equatable, Sendable {
    case missingStart
    case invalidWindowDays
    case invalidMaxRequests
}

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

    public func makeRequests(
        reminderID: UUID,
        proposal: ReminderProposal,
        windowStart: Date,
        windowDays: Int = 90,
        maxRequests: Int = 60
    ) throws -> [UNNotificationRequest] {
        try proposal.validate()
        guard let anchor = proposal.start else {
            throw ReminderRequestFactoryError.missingStart
        }
        guard windowDays > 0,
              let windowEnd = calendar.date(
                  byAdding: .day,
                  value: windowDays,
                  to: windowStart
              ) else {
            throw ReminderRequestFactoryError.invalidWindowDays
        }
        guard maxRequests > 0 else {
            throw ReminderRequestFactoryError.invalidMaxRequests
        }

        let prefix = "diary.reminder.v1.\(reminderID.uuidString)"
        return ReminderOccurrenceExpander(calendar: calendar).dates(
            recurrence: proposal.recurrence,
            anchor: anchor,
            windowStart: windowStart,
            windowEnd: windowEnd,
            leadMinutes: proposal.notificationLeadMinutes
        ).sorted().prefix(maxRequests).map { fireDate in
            makeRequest(
                id: "\(prefix).at.\(Int64(fireDate.timeIntervalSince1970))",
                title: proposal.title,
                body: proposal.notes,
                fireDate: fireDate
            )
        }
    }
}
