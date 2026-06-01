import Foundation
import UserNotifications

public enum ReminderSchedulingCoordinatorError: Error, Equatable, Sendable {
    case invalidStatus(ReminderProposalStatus)
    case cleanupFailed
}

@MainActor
public protocol ReminderPersistence: AnyObject {
    func reminder(id: UUID) throws -> ReminderRecord
    func reminderProposal(from record: ReminderRecord) throws -> ReminderProposal
    func updateReminderExecution(
        id: UUID,
        status: ReminderProposalStatus,
        notificationResult: ReminderExecutionResult,
        calendarResult: ReminderExecutionResult,
        notificationIdentifiers: [String],
        calendarEventIdentifier: String?,
        calendarExternalIdentifier: String?
    ) throws
    func resetReminderExecution(id: UUID) throws
    func updateReminderProposal(id: UUID, proposal: ReminderProposal) throws
    func cancelReminder(id: UUID) throws
}

@MainActor
public final class ReminderSchedulingCoordinator {
    typealias RequestFactory = (UUID, ReminderProposal, Date) throws -> [UNNotificationRequest]

    private let repository: any ReminderPersistence
    private let notificationClient: ReminderNotificationClient
    private let calendarClient: CalendarClient
    private let cleanupJournal: any ReminderCleanupJournaling
    private let makeRequests: RequestFactory
    private let now: () -> Date

    public init(
        repository: any ReminderPersistence,
        notificationClient: ReminderNotificationClient,
        calendarClient: CalendarClient,
        cleanupJournal: any ReminderCleanupJournaling = FileReminderCleanupJournal(),
        requestFactory: ReminderRequestFactory = ReminderRequestFactory(),
        now: @escaping () -> Date = Date.init
    ) {
        self.repository = repository
        self.notificationClient = notificationClient
        self.calendarClient = calendarClient
        self.cleanupJournal = cleanupJournal
        makeRequests = { reminderID, proposal, windowStart in
            try requestFactory.makeRequests(
                reminderID: reminderID,
                proposal: proposal,
                windowStart: windowStart
            )
        }
        self.now = now
    }

    init(
        repository: any ReminderPersistence,
        notificationClient: ReminderNotificationClient,
        calendarClient: CalendarClient,
        cleanupJournal: any ReminderCleanupJournaling = FileReminderCleanupJournal(),
        requestFactory: @escaping RequestFactory,
        now: @escaping () -> Date = Date.init
    ) {
        self.repository = repository
        self.notificationClient = notificationClient
        self.calendarClient = calendarClient
        self.cleanupJournal = cleanupJournal
        makeRequests = requestFactory
        self.now = now
    }

    public func confirm(reminderID: UUID) async throws {
        let record = try repository.reminder(id: reminderID)
        guard let status = ReminderProposalStatus(rawValue: record.status) else {
            throw DiaryRepositoryError.invalidReminderStatus(record.status)
        }
        guard status == .pendingConfirmation else {
            throw ReminderSchedulingCoordinatorError.invalidStatus(status)
        }
        let proposal = try repository.reminderProposal(from: record)
        var notificationResult: ReminderExecutionResult = proposal.notificationEnabled
            ? .pending
            : .notRequested
        var calendarResult: ReminderExecutionResult = proposal.calendarEnabled
            ? .pending
            : .notRequested
        var notificationIdentifiers: [String] = []
        var calendarReference: CalendarEventReference?

        try persist(
            reminderID: reminderID,
            status: .executing,
            notificationResult: notificationResult,
            calendarResult: calendarResult,
            notificationIdentifiers: notificationIdentifiers,
            calendarReference: calendarReference
        )

        if proposal.notificationEnabled {
            do {
                try Task.checkCancellation()
                let isAuthorized = try await notificationClient.requestAuthorization()
                try Task.checkCancellation()
                if isAuthorized {
                    let requests = try makeRequests(reminderID, proposal, now())
                    try Task.checkCancellation()
                    try await notificationClient.add(requests)
                    notificationIdentifiers = requests.map(\.identifier)
                    do {
                        try saveCleanupJournal(
                            reminderID: reminderID,
                            notificationIdentifiers: notificationIdentifiers,
                            calendarReference: calendarReference
                        )
                    } catch {
                        notificationClient.removePendingRequests(
                            withIdentifiers: notificationIdentifiers
                        )
                        notificationIdentifiers = []
                        throw error
                    }
                    try Task.checkCancellation()
                    notificationResult = .scheduled
                } else {
                    notificationResult = .permissionDenied
                }
            } catch {
                if error is CancellationError {
                    try compensate(
                        reminderID: reminderID,
                        notificationResult: notificationResult,
                        calendarResult: calendarResult,
                        notificationIdentifiers: notificationIdentifiers,
                        calendarReference: calendarReference
                    )
                    throw error
                }
                notificationResult = .failed
            }
            do {
                try persist(
                    reminderID: reminderID,
                    status: .executing,
                    notificationResult: notificationResult,
                    calendarResult: calendarResult,
                    notificationIdentifiers: notificationIdentifiers,
                    calendarReference: calendarReference
                )
            } catch {
                try compensate(
                    reminderID: reminderID,
                    notificationResult: notificationResult,
                    calendarResult: calendarResult,
                    notificationIdentifiers: notificationIdentifiers,
                    calendarReference: calendarReference
                )
                throw error
            }
        }

        if proposal.calendarEnabled {
            do {
                try Task.checkCancellation()
                let isAuthorized = try await calendarClient.requestFullAccess()
                try Task.checkCancellation()
                if isAuthorized {
                    try Task.checkCancellation()
                    calendarReference = try await calendarClient.createEvent(for: proposal)
                    do {
                        try saveCleanupJournal(
                            reminderID: reminderID,
                            notificationIdentifiers: notificationIdentifiers,
                            calendarReference: calendarReference
                        )
                    } catch {
                        guard let createdReference = calendarReference else {
                            throw error
                        }
                        do {
                            try calendarClient.removeEvent(reference: createdReference)
                            calendarReference = nil
                        } catch {
                            throw ReminderSchedulingCoordinatorError.cleanupFailed
                        }
                        throw error
                    }
                    try Task.checkCancellation()
                    calendarResult = .created
                } else {
                    calendarResult = .permissionDenied
                }
            } catch {
                if error is CancellationError {
                    try compensate(
                        reminderID: reminderID,
                        notificationResult: notificationResult,
                        calendarResult: calendarResult,
                        notificationIdentifiers: notificationIdentifiers,
                        calendarReference: calendarReference
                    )
                    throw error
                }
                calendarResult = .failed
            }
        }

        do {
            try persist(
                reminderID: reminderID,
                status: .scheduled,
                notificationResult: notificationResult,
                calendarResult: calendarResult,
                notificationIdentifiers: notificationIdentifiers,
                calendarReference: calendarReference
            )
            try cleanupJournal.remove(reminderID: reminderID)
        } catch {
            try compensate(
                reminderID: reminderID,
                notificationResult: notificationResult,
                calendarResult: calendarResult,
                notificationIdentifiers: notificationIdentifiers,
                calendarReference: calendarReference
            )
            throw error
        }
    }

    public func edit(reminderID: UUID, proposal: ReminderProposal) throws {
        try proposal.validate()
        let record = try repository.reminder(id: reminderID)
        try rejectExecuting(record)
        try removeOutputs(for: record, reminderID: reminderID)
        try repository.resetReminderExecution(id: reminderID)
        try cleanupJournal.remove(reminderID: reminderID)
        try repository.updateReminderProposal(id: reminderID, proposal: proposal)
    }

    public func cancel(reminderID: UUID) throws {
        let record = try repository.reminder(id: reminderID)
        try rejectExecuting(record)
        try removeOutputs(for: record, reminderID: reminderID)
        try repository.resetReminderExecution(id: reminderID)
        try cleanupJournal.remove(reminderID: reminderID)
        try repository.cancelReminder(id: reminderID)
    }

    public func recoverInterruptedExecution(reminderID: UUID) throws {
        let record = try repository.reminder(id: reminderID)
        let status = try status(of: record)
        guard status == .executing else {
            throw ReminderSchedulingCoordinatorError.invalidStatus(status)
        }
        if try cleanupJournal.load(reminderID: reminderID) == nil {
            try saveCleanupJournal(
                reminderID: reminderID,
                notificationIdentifiers: record.notificationIdentifiers,
                calendarReference: record.calendarEventIdentifier.map {
                    CalendarEventReference(
                        eventIdentifier: $0,
                        externalIdentifier: record.calendarExternalIdentifier
                    )
                }
            )
        }
        try removeOutputs(for: record, reminderID: reminderID)
        try repository.resetReminderExecution(id: reminderID)
        try cleanupJournal.remove(reminderID: reminderID)
    }

    private func rejectExecuting(_ record: ReminderRecord) throws {
        let status = try status(of: record)
        guard status != .executing else {
            throw ReminderSchedulingCoordinatorError.invalidStatus(status)
        }
    }

    private func status(of record: ReminderRecord) throws -> ReminderProposalStatus {
        guard let status = ReminderProposalStatus(rawValue: record.status) else {
            throw DiaryRepositoryError.invalidReminderStatus(record.status)
        }
        return status
    }

    private func removeOutputs(for record: ReminderRecord, reminderID: UUID) throws {
        let journalEntry = try cleanupJournal.load(reminderID: reminderID)
        let recordReference = record.calendarEventIdentifier.map {
            CalendarEventReference(
                eventIdentifier: $0,
                externalIdentifier: record.calendarExternalIdentifier
            )
        }
        if let reference = journalEntry?.calendarReference ?? recordReference {
            try calendarClient.removeEvent(
                reference: reference
            )
        }
        notificationClient.removePendingRequests(
            withIdentifiers: stableUniqued(
                record.notificationIdentifiers
                    + (journalEntry?.notificationIdentifiers ?? [])
            )
        )
    }

    private func persist(
        reminderID: UUID,
        status: ReminderProposalStatus,
        notificationResult: ReminderExecutionResult,
        calendarResult: ReminderExecutionResult,
        notificationIdentifiers: [String],
        calendarReference: CalendarEventReference?
    ) throws {
        try repository.updateReminderExecution(
            id: reminderID,
            status: status,
            notificationResult: notificationResult,
            calendarResult: calendarResult,
            notificationIdentifiers: notificationIdentifiers,
            calendarEventIdentifier: calendarReference?.eventIdentifier,
            calendarExternalIdentifier: calendarReference?.externalIdentifier
        )
    }

    private func compensate(
        reminderID: UUID,
        notificationResult: ReminderExecutionResult,
        calendarResult: ReminderExecutionResult,
        notificationIdentifiers: [String],
        calendarReference: CalendarEventReference?
    ) throws {
        let record = try? repository.reminder(id: reminderID)
        let journalEntry = try? cleanupJournal.load(reminderID: reminderID)
        let persistedCalendarReference = record?.calendarEventIdentifier.map {
            CalendarEventReference(
                eventIdentifier: $0,
                externalIdentifier: record?.calendarExternalIdentifier
            )
        }
        let identifiers = stableUniqued(
            notificationIdentifiers
                + (record?.notificationIdentifiers ?? [])
                + (journalEntry?.notificationIdentifiers ?? [])
        )
        let recoveryReference = calendarReference
            ?? journalEntry?.calendarReference
            ?? persistedCalendarReference
        try saveCleanupJournal(
            reminderID: reminderID,
            notificationIdentifiers: identifiers,
            calendarReference: recoveryReference
        )
        try? persist(
            reminderID: reminderID,
            status: .executing,
            notificationResult: notificationResult,
            calendarResult: calendarResult,
            notificationIdentifiers: identifiers,
            calendarReference: recoveryReference
        )
        var didFailCalendarCleanup = false
        if let recoveryReference {
            do {
                try calendarClient.removeEvent(reference: recoveryReference)
            } catch {
                didFailCalendarCleanup = true
            }
        }
        if !identifiers.isEmpty {
            notificationClient.removePendingRequests(withIdentifiers: identifiers)
        }
        guard !didFailCalendarCleanup else {
            throw ReminderSchedulingCoordinatorError.cleanupFailed
        }
        try repository.resetReminderExecution(id: reminderID)
        try cleanupJournal.remove(reminderID: reminderID)
    }

    private func saveCleanupJournal(
        reminderID: UUID,
        notificationIdentifiers: [String],
        calendarReference: CalendarEventReference?
    ) throws {
        guard calendarReference != nil || !notificationIdentifiers.isEmpty else {
            return
        }
        try cleanupJournal.save(
            reminderID: reminderID,
            entry: ReminderCleanupJournalEntry(
                calendarReference: calendarReference,
                notificationIdentifiers: stableUniqued(notificationIdentifiers)
            )
        )
    }

    private func stableUniqued(_ identifiers: [String]) -> [String] {
        var seen: Set<String> = []
        return identifiers.filter { seen.insert($0).inserted }
    }
}
