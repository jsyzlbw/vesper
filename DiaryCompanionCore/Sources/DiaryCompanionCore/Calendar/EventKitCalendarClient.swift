import EventKit
import Foundation

@MainActor
public protocol CalendarClient: AnyObject {
    func requestFullAccess() async throws -> Bool
    func busyIntervals(in searchWindow: DateInterval) async throws -> [DateInterval]
    func createEvent(for proposal: ReminderProposal) async throws -> String
    func removeEvent(identifier: String) throws
}

public enum EventKitCalendarClientError: Error, Equatable, Sendable {
    case missingStart
    case missingDefaultCalendar
    case missingEventIdentifier
    case eventNotFound(String)
}

@MainActor
public final class EventKitCalendarClient: CalendarClient {
    private let eventStore: EKEventStore

    public init(eventStore: EKEventStore = EKEventStore()) {
        self.eventStore = eventStore
    }

    public func requestFullAccess() async throws -> Bool {
        try await eventStore.requestFullAccessToEvents()
    }

    public func busyIntervals(
        in searchWindow: DateInterval
    ) async throws -> [DateInterval] {
        let calendars = eventStore.calendars(for: .event)
        let predicate = eventStore.predicateForEvents(
            withStart: searchWindow.start,
            end: searchWindow.end,
            calendars: calendars
        )

        return eventStore.events(matching: predicate).map {
            DateInterval(start: $0.startDate, end: $0.endDate)
        }
    }

    public func createEvent(for proposal: ReminderProposal) async throws -> String {
        guard let start = proposal.start else {
            throw EventKitCalendarClientError.missingStart
        }
        guard let calendar = eventStore.defaultCalendarForNewEvents else {
            throw EventKitCalendarClientError.missingDefaultCalendar
        }

        let event = EKEvent(eventStore: eventStore)
        event.calendar = calendar
        event.title = proposal.title
        event.notes = proposal.notes
        event.startDate = start
        event.endDate = start.addingTimeInterval(
            TimeInterval(proposal.durationMinutes) * 60
        )
        if let recurrenceRule = proposal.recurrence.eventKitRule {
            event.addRecurrenceRule(recurrenceRule)
        }

        try eventStore.save(event, span: .thisEvent)
        guard let identifier = event.eventIdentifier else {
            throw EventKitCalendarClientError.missingEventIdentifier
        }
        return identifier
    }

    public func removeEvent(identifier: String) throws {
        guard let event = eventStore.event(withIdentifier: identifier) else {
            throw EventKitCalendarClientError.eventNotFound(identifier)
        }
        try eventStore.remove(event, span: .thisEvent)
    }
}

private extension ReminderRecurrenceRule {
    var eventKitRule: EKRecurrenceRule? {
        switch self {
        case .once:
            return nil
        case let .daily(interval, end):
            return EKRecurrenceRule(
                recurrenceWith: .daily,
                interval: interval,
                end: end?.eventKitEnd
            )
        case let .weekly(interval, weekdays, end):
            return EKRecurrenceRule(
                recurrenceWith: .weekly,
                interval: interval,
                daysOfTheWeek: weekdays.map(\.eventKitWeekday),
                daysOfTheMonth: nil,
                monthsOfTheYear: nil,
                weeksOfTheYear: nil,
                daysOfTheYear: nil,
                setPositions: nil,
                end: end?.eventKitEnd
            )
        case let .monthly(interval, day, end):
            return EKRecurrenceRule(
                recurrenceWith: .monthly,
                interval: interval,
                daysOfTheWeek: nil,
                daysOfTheMonth: [day as NSNumber],
                monthsOfTheYear: nil,
                weeksOfTheYear: nil,
                daysOfTheYear: nil,
                setPositions: nil,
                end: end?.eventKitEnd
            )
        case let .monthlyLastDay(interval, end):
            return EKRecurrenceRule(
                recurrenceWith: .monthly,
                interval: interval,
                daysOfTheWeek: nil,
                daysOfTheMonth: [-1 as NSNumber],
                monthsOfTheYear: nil,
                weeksOfTheYear: nil,
                daysOfTheYear: nil,
                setPositions: nil,
                end: end?.eventKitEnd
            )
        case let .yearly(interval, month, day, end):
            return EKRecurrenceRule(
                recurrenceWith: .yearly,
                interval: interval,
                daysOfTheWeek: nil,
                daysOfTheMonth: [day as NSNumber],
                monthsOfTheYear: [month as NSNumber],
                weeksOfTheYear: nil,
                daysOfTheYear: nil,
                setPositions: nil,
                end: end?.eventKitEnd
            )
        }
    }
}

private extension ReminderRecurrenceEnd {
    var eventKitEnd: EKRecurrenceEnd {
        switch self {
        case let .date(date):
            return EKRecurrenceEnd(end: date)
        case let .occurrenceCount(count):
            return EKRecurrenceEnd(occurrenceCount: count)
        }
    }
}

private extension ReminderWeekday {
    var eventKitWeekday: EKRecurrenceDayOfWeek {
        EKRecurrenceDayOfWeek(EKWeekday(rawValue: rawValue)!)
    }
}
