import Foundation
import UserNotifications

public enum ReminderSchedulingCoordinatorError: Error, Equatable, Sendable {
    case invalidStatus(ReminderProposalStatus)
}

@MainActor
public final class ReminderSchedulingCoordinator {
    typealias RequestFactory = (UUID, ReminderProposal, Date) throws -> [UNNotificationRequest]

    private let repository: DiaryRepository
    private let notificationClient: ReminderNotificationClient
    private let calendarClient: CalendarClient
    private let makeRequests: RequestFactory
    private let now: () -> Date

    public init(
        repository: DiaryRepository,
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
        repository: DiaryRepository,
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
                notificationResult = .failed
            }
            try persist(
                reminderID: reminderID,
                status: .executing,
                notificationResult: notificationResult,
                calendarResult: calendarResult,
                notificationIdentifiers: notificationIdentifiers,
                calendarReference: calendarReference
            )
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
                calendarResult = .failed
            }
        }

        try persist(
            reminderID: reminderID,
            status: .scheduled,
            notificationResult: notificationResult,
            calendarResult: calendarResult,
            notificationIdentifiers: notificationIdentifiers,
            calendarReference: calendarReference
        )
    }

    public func edit(reminderID: UUID, proposal: ReminderProposal) throws {
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

    private func rejectExecuting(_ record: ReminderRecord) throws {
        guard let status = ReminderProposalStatus(rawValue: record.status) else {
            throw DiaryRepositoryError.invalidReminderStatus(record.status)
        }
        guard status != .executing else {
            throw ReminderSchedulingCoordinatorError.invalidStatus(status)
        }
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
}
