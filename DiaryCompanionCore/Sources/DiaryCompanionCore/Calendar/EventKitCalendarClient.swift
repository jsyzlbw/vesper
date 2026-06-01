import EventKit
import Foundation

public struct CalendarEventReference: Codable, Equatable, Sendable {
    public var eventIdentifier: String
    public var externalIdentifier: String?

    public init(eventIdentifier: String, externalIdentifier: String?) {
        self.eventIdentifier = eventIdentifier
        self.externalIdentifier = externalIdentifier?.isEmpty == false
            ? externalIdentifier
            : nil
    }
}

@MainActor
public protocol CalendarClient: AnyObject {
    func requestFullAccess() async throws -> Bool
    func busyIntervals(in searchWindow: DateInterval) async throws -> [DateInterval]
    func createEvent(for proposal: ReminderProposal) async throws -> CalendarEventReference
    func removeEvent(reference: CalendarEventReference) throws
}

public enum EventKitCalendarClientError: Error, Equatable, Sendable {
    case missingStart
    case missingDefaultCalendar
    case missingEventIdentifier
    case eventNotFound(String)
    case ambiguousExternalIdentifier(String)
}

enum EventLookupResolution: Equatable {
    case primary
    case externalCandidate
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

        return eventStore.events(matching: predicate).compactMap {
            Self.interval(
                start: $0.startDate,
                end: $0.endDate,
                availability: $0.availability,
                within: searchWindow
            )
        }
    }

    public func createEvent(
        for proposal: ReminderProposal
    ) async throws -> CalendarEventReference {
        try proposal.validate()
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
        return CalendarEventReference(
            eventIdentifier: identifier,
            externalIdentifier: event.calendarItemExternalIdentifier
        )
    }

    public func removeEvent(reference: CalendarEventReference) throws {
        let primaryEvent = eventStore.event(withIdentifier: reference.eventIdentifier)
        let externalCandidates: [EKEvent]
        if primaryEvent == nil, let externalIdentifier = reference.externalIdentifier {
            externalCandidates = eventStore
                .calendarItems(withExternalIdentifier: externalIdentifier)
                .compactMap { $0 as? EKEvent }
        } else {
            externalCandidates = []
        }
        let resolution = try Self.eventLookupResolution(
            eventIdentifier: reference.eventIdentifier,
            primaryExists: primaryEvent != nil,
            externalIdentifier: reference.externalIdentifier,
            externalCandidatesCount: externalCandidates.count
        )
        let event: EKEvent
        switch resolution {
        case .primary:
            event = primaryEvent!
        case .externalCandidate:
            event = externalCandidates[0]
        }
        try eventStore.remove(
            event,
            span: Self.removalSpan(hasRecurrenceRules: event.hasRecurrenceRules)
        )
    }

    @available(*, deprecated, message: "Use removeEvent(reference:) to preserve lookup fallback.")
    public func removeEvent(identifier: String) throws {
        try removeEvent(
            reference: CalendarEventReference(
                eventIdentifier: identifier,
                externalIdentifier: nil
            )
        )
    }

    nonisolated static func eventLookupResolution(
        eventIdentifier: String = "",
        primaryExists: Bool,
        externalIdentifier: String?,
        externalCandidatesCount: Int
    ) throws -> EventLookupResolution {
        if primaryExists {
            return .primary
        }
        guard let externalIdentifier, !externalIdentifier.isEmpty else {
            throw EventKitCalendarClientError.eventNotFound(eventIdentifier)
        }
        switch externalCandidatesCount {
        case 0:
            throw EventKitCalendarClientError.eventNotFound(eventIdentifier)
        case 1:
            return .externalCandidate
        default:
            throw EventKitCalendarClientError.ambiguousExternalIdentifier(
                externalIdentifier
            )
        }
    }

    nonisolated static func interval(
        start: Date?,
        end: Date?,
        availability: EKEventAvailability,
        within searchWindow: DateInterval
    ) -> DateInterval? {
        guard availability != .free, let start, let end, end > start else {
            return nil
        }
        guard let clipped = DateInterval(start: start, end: end).intersection(
            with: searchWindow
        ), clipped.duration > 0 else {
            return nil
        }
        return clipped
    }

    nonisolated static func removalSpan(
        hasRecurrenceRules: Bool
    ) -> EKSpan {
        hasRecurrenceRules ? .futureEvents : .thisEvent
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
