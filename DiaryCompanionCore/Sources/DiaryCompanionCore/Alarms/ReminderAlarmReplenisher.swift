import Foundation

public enum ReminderAlarmReplenisherError: Error, Equatable, Sendable {
    case invalidMaxAlarms
}

@MainActor
public final class ReminderAlarmReplenisher {
    private struct Candidate {
        var reminderID: UUID
        var occurrence: AlarmOccurrence
    }

    private struct Context {
        var record: ReminderRecord
        var proposal: ReminderProposal
    }

    private let repository: any ReminderReplenishmentPersistence
    private let alarmClient: any AlarmClient
    private let occurrenceFactory: AlarmOccurrenceFactory
    private let maxAlarms: Int

    public init(
        repository: any ReminderReplenishmentPersistence,
        alarmClient: any AlarmClient,
        occurrenceFactory: AlarmOccurrenceFactory = AlarmOccurrenceFactory(),
        maxAlarms: Int = 60
    ) {
        self.repository = repository
        self.alarmClient = alarmClient
        self.occurrenceFactory = occurrenceFactory
        self.maxAlarms = maxAlarms
    }

    public func replenish(windowStart: Date = Date()) async throws {
        guard maxAlarms > 0 else {
            throw ReminderAlarmReplenisherError.invalidMaxAlarms
        }
        let records = try repository.fetchReminders().filter {
            $0.status == ReminderProposalStatus.scheduled.rawValue
                && $0.alarmEnabled
        }
        let contexts = try records.map {
            Context(
                record: $0,
                proposal: try repository.reminderProposal(from: $0)
            )
        }
        let selected = try contexts.flatMap { context in
            try occurrenceFactory.occurrences(
                reminderID: context.record.id,
                proposal: context.proposal,
                windowStart: windowStart,
                maxDates: maxAlarms
            ).map {
                Candidate(reminderID: context.record.id, occurrence: $0)
            }
        }.sorted {
            if $0.occurrence.fireDate == $1.occurrence.fireDate {
                return $0.occurrence.identifier.uuidString
                    < $1.occurrence.identifier.uuidString
            }
            return $0.occurrence.fireDate < $1.occurrence.fireDate
        }.prefix(maxAlarms)

        for context in contexts {
            let record = context.record
            let expected = selected
                .filter { $0.reminderID == record.id }
                .map(\.occurrence)
            let expectedIdentifiers = Set(expected.map { $0.identifier.uuidString })
            let existingIdentifiers = Set(record.alarmIdentifiers)
            let missing = expected.filter {
                !existingIdentifiers.contains($0.identifier.uuidString)
            }
            if !missing.isEmpty {
                try await alarmClient.schedule(
                    reminderID: record.id,
                    proposal: context.proposal,
                    occurrences: missing
                )
            }
            let stale = existingIdentifiers.subtracting(expectedIdentifiers).sorted()
            if !stale.isEmpty {
                try alarmClient.remove(ids: stale)
            }
            try repository.updateReminderExecution(
                id: record.id,
                status: .scheduled,
                notificationResult: ReminderExecutionResult(
                    rawValue: record.notificationResult
                ) ?? .notRequested,
                alarmResult: .scheduled,
                calendarResult: ReminderExecutionResult(rawValue: record.calendarResult)
                    ?? .notRequested,
                notificationIdentifiers: record.notificationIdentifiers,
                alarmIdentifiers: expected.map { $0.identifier.uuidString },
                calendarEventIdentifier: record.calendarEventIdentifier,
                calendarExternalIdentifier: record.calendarExternalIdentifier
            )
        }
    }
}
