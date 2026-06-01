import Foundation
import UserNotifications

public enum ReminderSchedulingCoordinatorError: Error, Equatable, Sendable {
    case invalidStatus(ReminderProposalStatus)
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
    private let makeRequests: RequestFactory
    private let now: () -> Date

    public init(
        repository: any ReminderPersistence,
        notificationClient: ReminderNotificationClient,
        calendarClient: CalendarClient,
        requestFactory: ReminderRequestFactory = ReminderRequestFactory(),
        now: @escaping () -> Date = Date.init
    ) {
        self.repository = repository
        self.notificationClient = notificationClient
        self.calendarClient = calendarClient
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
        requestFactory: @escaping RequestFactory,
        now: @escaping () -> Date = Date.init
    ) {
        self.repository = repository
        self.notificationClient = notificationClient
        self.calendarClient = calendarClient
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
                if try await notificationClient.requestAuthorization() {
                    let requests = try makeRequests(reminderID, proposal, now())
                    try await notificationClient.add(requests)
                    notificationIdentifiers = requests.map(\.identifier)
                    notificationResult = .scheduled
                } else {
                    notificationResult = .permissionDenied
                }
            } catch {
                if error is CancellationError {
                    compensate(
                        reminderID: reminderID,
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
                compensate(
                    reminderID: reminderID,
                    notificationIdentifiers: notificationIdentifiers,
                    calendarReference: calendarReference
                )
                throw error
            }
        }

        if proposal.calendarEnabled {
            do {
                if try await calendarClient.requestFullAccess() {
                    calendarReference = try await calendarClient.createEvent(for: proposal)
                    calendarResult = .created
                } else {
                    calendarResult = .permissionDenied
                }
            } catch {
                if error is CancellationError {
                    compensate(
                        reminderID: reminderID,
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
        } catch {
            compensate(
                reminderID: reminderID,
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
        try removeOutputs(for: record)
        try repository.resetReminderExecution(id: reminderID)
        try repository.updateReminderProposal(id: reminderID, proposal: proposal)
    }

    public func cancel(reminderID: UUID) throws {
        let record = try repository.reminder(id: reminderID)
        try rejectExecuting(record)
        try removeOutputs(for: record)
        try repository.resetReminderExecution(id: reminderID)
        try repository.cancelReminder(id: reminderID)
    }

    public func recoverInterruptedExecution(reminderID: UUID) throws {
        let record = try repository.reminder(id: reminderID)
        let status = try status(of: record)
        guard status == .executing else {
            throw ReminderSchedulingCoordinatorError.invalidStatus(status)
        }
        try removeOutputs(for: record)
        try repository.resetReminderExecution(id: reminderID)
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

    private func removeOutputs(for record: ReminderRecord) throws {
        if let identifier = record.calendarEventIdentifier {
            try calendarClient.removeEvent(
                reference: CalendarEventReference(
                    eventIdentifier: identifier,
                    externalIdentifier: record.calendarExternalIdentifier
                )
            )
        }
        notificationClient.removePendingRequests(
            withIdentifiers: record.notificationIdentifiers
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
        notificationIdentifiers: [String],
        calendarReference: CalendarEventReference?
    ) {
        let record = try? repository.reminder(id: reminderID)
        let persistedCalendarReference = record?.calendarEventIdentifier.map {
            CalendarEventReference(
                eventIdentifier: $0,
                externalIdentifier: record?.calendarExternalIdentifier
            )
        }
        if let calendarReference = calendarReference ?? persistedCalendarReference {
            try? calendarClient.removeEvent(reference: calendarReference)
        }
        let identifiers = stableUniqued(
            notificationIdentifiers + (record?.notificationIdentifiers ?? [])
        )
        if !identifiers.isEmpty {
            notificationClient.removePendingRequests(withIdentifiers: identifiers)
        }
        try? repository.resetReminderExecution(id: reminderID)
    }

    private func stableUniqued(_ identifiers: [String]) -> [String] {
        var seen: Set<String> = []
        return identifiers.filter { seen.insert($0).inserted }
    }
}
