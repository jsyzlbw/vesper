import Foundation

@MainActor
public protocol AlarmClient: AnyObject {
    func requestAuthorization() async throws -> Bool
    func schedule(
        reminderID: UUID,
        proposal: ReminderProposal,
        windowStart: Date
    ) async throws -> [String]
    func remove(ids: [String]) throws
}

public enum AlarmClientError: Error, Equatable, Sendable {
    case alarmRequiresIOS26
    case authorizationDenied
}

public final class UnavailableAlarmClient: AlarmClient {
    public init() {}

    public func requestAuthorization() async throws -> Bool {
        throw AlarmClientError.alarmRequiresIOS26
    }

    public func schedule(
        reminderID: UUID,
        proposal: ReminderProposal,
        windowStart: Date
    ) async throws -> [String] {
        guard proposal.alarmEnabled else {
            return []
        }
        throw AlarmClientError.alarmRequiresIOS26
    }

    public func remove(ids: [String]) throws {}
}

public struct AlarmOccurrenceFactory: Sendable {
    private let calendar: Calendar

    public init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    public func dates(
        proposal: ReminderProposal,
        windowStart: Date,
        windowDays: Int = 90,
        maxDates: Int = 60
    ) throws -> [Date] {
        guard proposal.alarmEnabled else {
            return []
        }
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
        guard maxDates > 0 else {
            throw ReminderRequestFactoryError.invalidMaxRequests
        }

        return Array(
            ReminderOccurrenceExpander(calendar: calendar).dates(
                recurrence: proposal.recurrence,
                anchor: anchor,
                windowStart: windowStart,
                windowEnd: windowEnd,
                leadMinutes: proposal.alarmLeadMinutes
            ).sorted().prefix(maxDates)
        )
    }
}
