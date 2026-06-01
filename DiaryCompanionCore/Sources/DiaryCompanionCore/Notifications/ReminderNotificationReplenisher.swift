import Foundation
import UserNotifications

public enum ReminderNotificationReplenisherError: Error, Equatable, Sendable {
    case invalidMaxRequests
    case invalidNotificationTrigger(String)
}

@MainActor
public protocol ReminderReplenishmentPersistence: AnyObject {
    func fetchReminders() throws -> [ReminderRecord]
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
}

extension DiaryRepository: ReminderReplenishmentPersistence {}

@MainActor
public final class ReminderNotificationReplenisher {
    private struct Candidate {
        var reminderID: UUID
        var request: UNNotificationRequest
        var fireDate: Date
    }

    private let repository: any ReminderReplenishmentPersistence
    private let notificationClient: ReminderNotificationClient
    private let requestFactory: ReminderRequestFactory
    private let calendar: Calendar
    private let maxRequests: Int

    public init(
        repository: any ReminderReplenishmentPersistence,
        notificationClient: ReminderNotificationClient,
        requestFactory: ReminderRequestFactory = ReminderRequestFactory(),
        calendar: Calendar = .current,
        maxRequests: Int = 60
    ) {
        self.repository = repository
        self.notificationClient = notificationClient
        self.requestFactory = requestFactory
        self.calendar = calendar
        self.maxRequests = maxRequests
    }

    public func replenish(windowStart: Date = Date()) async throws {
        guard maxRequests > 0 else {
            throw ReminderNotificationReplenisherError.invalidMaxRequests
        }
        let records = try repository.fetchReminders().filter {
            $0.status == ReminderProposalStatus.scheduled.rawValue
                && $0.notificationEnabled
        }
        let candidates = try records.flatMap { record in
            try requestFactory.makeRequests(
                reminderID: record.id,
                proposal: repository.reminderProposal(from: record),
                windowStart: windowStart,
                maxRequests: maxRequests
            ).map {
                Candidate(
                    reminderID: record.id,
                    request: $0,
                    fireDate: try fireDate(of: $0)
                )
            }
        }.sorted {
            if $0.fireDate == $1.fireDate {
                return $0.request.identifier < $1.request.identifier
            }
            return $0.fireDate < $1.fireDate
        }

        let selected = Array(candidates.prefix(maxRequests))
        let selectedIdentifiers = Set(selected.map(\.request.identifier))
        let existingIdentifiers = Set(records.flatMap(\.notificationIdentifiers))
        let missing = selected
            .map(\.request)
            .filter { !existingIdentifiers.contains($0.identifier) }
        try await notificationClient.add(missing)

        let stale = existingIdentifiers.subtracting(selectedIdentifiers).sorted()
        if !stale.isEmpty {
            notificationClient.removePendingRequests(withIdentifiers: stale)
        }

        for record in records {
            let identifiers = selected
                .filter { $0.reminderID == record.id }
                .map(\.request.identifier)
            try repository.updateReminderExecution(
                id: record.id,
                status: .scheduled,
                notificationResult: .scheduled,
                calendarResult: ReminderExecutionResult(rawValue: record.calendarResult)
                    ?? .notRequested,
                notificationIdentifiers: identifiers,
                calendarEventIdentifier: record.calendarEventIdentifier,
                calendarExternalIdentifier: record.calendarExternalIdentifier
            )
        }
    }

    private func fireDate(of request: UNNotificationRequest) throws -> Date {
        guard let trigger = request.trigger as? UNCalendarNotificationTrigger,
              let date = calendar.date(from: trigger.dateComponents)
        else {
            throw ReminderNotificationReplenisherError
                .invalidNotificationTrigger(request.identifier)
        }
        return date
    }
}
