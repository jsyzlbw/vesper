import Foundation
import UserNotifications

public enum ReminderRequestFactoryError: Error, Equatable, Sendable {
    case missingStart
    case invalidWindowDays
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
        windowDays: Int = 90
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

        let prefix = "diary.reminder.v1.\(reminderID.uuidString)"
        return concreteOccurrences(
            recurrence: proposal.recurrence,
            anchor: anchor,
            windowStart: windowStart,
            windowEnd: windowEnd
        ).map { occurrence in
            makeRequest(
                id: "\(prefix).at.\(Int64(occurrence.timeIntervalSince1970))",
                title: proposal.title,
                body: proposal.notes,
                fireDate: occurrence
            )
        }
    }
}

private extension ReminderRequestFactory {
    func concreteOccurrences(
        recurrence: ReminderRecurrenceRule,
        anchor: Date,
        windowStart: Date,
        windowEnd: Date
    ) -> [Date] {
        var occurrences: [Date] = []
        var occurrenceCount = 0
        let end = recurrence.end

        func shouldContinue(_ occurrence: Date) -> Bool {
            guard occurrence < windowEnd else {
                return false
            }
            if case let .date(endDate) = end, occurrence > endDate {
                return false
            }
            if case let .occurrenceCount(limit) = end,
               occurrenceCount >= limit {
                return false
            }
            return true
        }

        func record(_ occurrence: Date) -> Bool {
            guard shouldContinue(occurrence) else {
                return false
            }
            occurrenceCount += 1
            if occurrence >= windowStart {
                occurrences.append(occurrence)
            }
            return true
        }

        switch recurrence {
        case .once:
            _ = record(anchor)
        case let .daily(interval, _):
            var offset = 0
            while let occurrence = calendar.date(
                byAdding: .day,
                value: offset,
                to: anchor
            ), record(occurrence) {
                offset += interval
            }
        case let .weekly(interval, weekdays, _):
            guard let anchorWeek = calendar.dateInterval(
                of: .weekOfYear,
                for: anchor
            )?.start else {
                return []
            }
            var weekOffset = 0
            weeklyLoop: while let week = calendar.date(
                byAdding: .weekOfYear,
                value: weekOffset,
                to: anchorWeek
            ), week < windowEnd {
                let weeklyOccurrences = weekdays.compactMap { weekday in
                    weeklyOccurrence(
                        in: week,
                        weekday: weekday,
                        anchor: anchor
                    )
                }.filter { $0 >= anchor }.sorted()
                for occurrence in weeklyOccurrences {
                    guard record(occurrence) else {
                        break weeklyLoop
                    }
                }
                weekOffset += interval
            }
        case let .monthly(interval, day, _):
            var monthOffset = 0
            while let month = calendar.date(
                byAdding: .month,
                value: monthOffset,
                to: startOfMonth(containing: anchor)
            ), month < windowEnd {
                if let occurrence = monthlyOccurrence(
                    in: month,
                    day: day,
                    anchor: anchor
                ), occurrence >= anchor, !record(occurrence) {
                    break
                }
                monthOffset += interval
            }
        case let .monthlyLastDay(interval, _):
            var monthOffset = 0
            while let month = calendar.date(
                byAdding: .month,
                value: monthOffset,
                to: startOfMonth(containing: anchor)
            ), month < windowEnd {
                if let lastDay = calendar.range(of: .day, in: .month, for: month)?.last,
                   let occurrence = monthlyOccurrence(
                       in: month,
                       day: lastDay,
                       anchor: anchor
                   ),
                   occurrence >= anchor,
                   !record(occurrence) {
                    break
                }
                monthOffset += interval
            }
        case let .yearly(interval, month, day, _):
            let anchorYear = calendar.component(.year, from: anchor)
            var yearOffset = 0
            while let occurrenceYear = calendar.date(
                from: DateComponents(year: anchorYear + yearOffset)
            ), occurrenceYear < windowEnd {
                if let occurrence = yearlyOccurrence(
                    year: anchorYear + yearOffset,
                    month: month,
                    day: day,
                    anchor: anchor
                ), occurrence >= anchor, !record(occurrence) {
                    break
                }
                yearOffset += interval
            }
        }

        return occurrences
    }

    func weeklyOccurrence(
        in week: Date,
        weekday: ReminderWeekday,
        anchor: Date
    ) -> Date? {
        let anchorTime = calendar.dateComponents([.hour, .minute], from: anchor)
        var components = calendar.dateComponents(
            [.yearForWeekOfYear, .weekOfYear],
            from: week
        )
        components.weekday = weekday.rawValue
        components.hour = anchorTime.hour
        components.minute = anchorTime.minute
        return calendar.date(from: components)
    }

    func startOfMonth(containing date: Date) -> Date {
        calendar.date(
            from: calendar.dateComponents([.year, .month], from: date)
        )!
    }

    func monthlyOccurrence(in month: Date, day: Int, anchor: Date) -> Date? {
        let monthComponents = calendar.dateComponents([.year, .month], from: month)
        let anchorTime = calendar.dateComponents([.hour, .minute], from: anchor)
        var components = monthComponents
        components.day = day
        components.hour = anchorTime.hour
        components.minute = anchorTime.minute
        guard let occurrence = calendar.date(from: components) else {
            return nil
        }
        let resolved = calendar.dateComponents([.year, .month, .day], from: occurrence)
        guard resolved.year == components.year,
              resolved.month == components.month,
              resolved.day == components.day else {
            return nil
        }
        return occurrence
    }

    func yearlyOccurrence(
        year: Int,
        month: Int,
        day: Int,
        anchor: Date
    ) -> Date? {
        let anchorTime = calendar.dateComponents([.hour, .minute], from: anchor)
        var components = DateComponents(year: year, month: month, day: day)
        components.hour = anchorTime.hour
        components.minute = anchorTime.minute
        guard let occurrence = calendar.date(from: components) else {
            return nil
        }
        let resolved = calendar.dateComponents([.year, .month, .day], from: occurrence)
        guard resolved.year == year,
              resolved.month == month,
              resolved.day == day else {
            return nil
        }
        return occurrence
    }
}

private extension ReminderRecurrenceRule {
    var end: ReminderRecurrenceEnd? {
        switch self {
        case .once:
            nil
        case let .daily(_, end),
             let .weekly(_, _, end),
             let .monthly(_, _, end),
             let .monthlyLastDay(_, end),
             let .yearly(_, _, _, end):
            end
        }
    }
}
