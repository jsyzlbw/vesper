import Foundation

@MainActor
public protocol AlarmClient: AnyObject {
    func requestAuthorization() async throws -> Bool
    /// Schedules the complete batch atomically. Implementations remove any
    /// alarms created by this call before throwing an error.
    func schedule(
        reminderID: UUID,
        proposal: ReminderProposal,
        occurrences: [AlarmOccurrence]
    ) async throws
    /// Removes identifiers idempotently. Missing alarms are already removed.
    func remove(ids: [String]) throws
}

public enum AlarmClientError: Error, Equatable, Sendable {
    case alarmRequiresIOS26
    case authorizationDenied
    case rollbackFailed([String])
}

public struct AlarmOccurrence: Equatable, Sendable {
    public var identifier: UUID
    public var fireDate: Date

    public init(identifier: UUID, fireDate: Date) {
        self.identifier = identifier
        self.fireDate = fireDate
    }
}

public final class UnavailableAlarmClient: AlarmClient {
    public init() {}

    public func requestAuthorization() async throws -> Bool {
        throw AlarmClientError.alarmRequiresIOS26
    }

    public func schedule(
        reminderID: UUID,
        proposal: ReminderProposal,
        occurrences: [AlarmOccurrence]
    ) async throws {
        guard proposal.alarmEnabled else {
            return
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

    public func occurrences(
        reminderID: UUID,
        proposal: ReminderProposal,
        windowStart: Date,
        windowDays: Int = 90,
        maxDates: Int = 60
    ) throws -> [AlarmOccurrence] {
        try dates(
            proposal: proposal,
            windowStart: windowStart,
            windowDays: windowDays,
            maxDates: maxDates
        ).map { fireDate in
            AlarmOccurrence(
                identifier: stableIdentifier(
                    reminderID: reminderID,
                    fireDate: fireDate
                ),
                fireDate: fireDate
            )
        }
    }

    private func stableIdentifier(reminderID: UUID, fireDate: Date) -> UUID {
        let seed = "\(reminderID.uuidString.lowercased()).\(Int64(fireDate.timeIntervalSince1970))"
        let bytes = Array(seed.utf8)
        let first = fnv1a64(bytes, offset: 0xcbf29ce484222325)
        let second = fnv1a64(bytes.reversed(), offset: 0x84222325cbf29ce4)
        var uuidBytes = withUnsafeBytes(of: (first.bigEndian, second.bigEndian)) {
            Array($0)
        }
        uuidBytes[6] = (uuidBytes[6] & 0x0f) | 0x80
        uuidBytes[8] = (uuidBytes[8] & 0x3f) | 0x80
        return UUID(uuid: (
            uuidBytes[0], uuidBytes[1], uuidBytes[2], uuidBytes[3],
            uuidBytes[4], uuidBytes[5], uuidBytes[6], uuidBytes[7],
            uuidBytes[8], uuidBytes[9], uuidBytes[10], uuidBytes[11],
            uuidBytes[12], uuidBytes[13], uuidBytes[14], uuidBytes[15]
        ))
    }

    private func fnv1a64<S: Sequence>(
        _ bytes: S,
        offset: UInt64
    ) -> UInt64 where S.Element == UInt8 {
        bytes.reduce(offset) { hash, byte in
            (hash ^ UInt64(byte)) &* 0x100000001b3
        }
    }
}
