import Foundation
import SwiftData
import Testing
import UserNotifications
@testable import DiaryCompanionCore

@MainActor
@Test func creatingProposalHasNoSchedulingSideEffects() throws {
    let fixture = try CoordinatorFixture()

    _ = try fixture.repository.createReminderProposal(fixture.proposal, sourceMessageID: nil)

    #expect(fixture.notifications.authorizationRequestCount == 0)
    #expect(fixture.calendar.authorizationRequestCount == 0)
}

@MainActor
@Test func confirmSchedulesBothOutputsAndPersistsIdentifiers() async throws {
    let fixture = try CoordinatorFixture()
    let record = try fixture.makeRecord()

    try await fixture.coordinator.confirm(reminderID: record.id)

    #expect(record.status == ReminderProposalStatus.scheduled.rawValue)
    #expect(record.notificationResult == ReminderExecutionResult.scheduled.rawValue)
    #expect(record.calendarResult == ReminderExecutionResult.created.rawValue)
    #expect(record.notificationIdentifiers == fixture.expectedNotificationIDs)
    #expect(record.calendarEventIdentifier == "event-1")
    #expect(record.calendarExternalIdentifier == "external-1")
}

@MainActor
@Test func confirmSchedulesNotificationsWhenCalendarPermissionIsDenied() async throws {
    let fixture = try CoordinatorFixture()
    fixture.calendar.authorizationGranted = false
    let record = try fixture.makeRecord()

    try await fixture.coordinator.confirm(reminderID: record.id)

    #expect(record.notificationResult == ReminderExecutionResult.scheduled.rawValue)
    #expect(record.calendarResult == ReminderExecutionResult.permissionDenied.rawValue)
}

@MainActor
@Test func confirmCreatesCalendarEventWhenNotificationPermissionIsDenied() async throws {
    let fixture = try CoordinatorFixture()
    fixture.notifications.authorizationGranted = false
    let record = try fixture.makeRecord()

    try await fixture.coordinator.confirm(reminderID: record.id)

    #expect(record.notificationResult == ReminderExecutionResult.permissionDenied.rawValue)
    #expect(record.calendarResult == ReminderExecutionResult.created.rawValue)
}

@MainActor
@Test func confirmAttemptsCalendarAfterNotificationThrows() async throws {
    let fixture = try CoordinatorFixture()
    fixture.notifications.requestAuthorizationError = FixtureError.failed
    let record = try fixture.makeRecord()

    try await fixture.coordinator.confirm(reminderID: record.id)

    #expect(record.notificationResult == ReminderExecutionResult.failed.rawValue)
    #expect(fixture.calendar.createEventCount == 1)
    #expect(record.calendarResult == ReminderExecutionResult.created.rawValue)
}

@MainActor
@Test func confirmAttemptsNotificationsAfterCalendarThrows() async throws {
    let fixture = try CoordinatorFixture()
    fixture.calendar.requestAuthorizationError = FixtureError.failed
    let record = try fixture.makeRecord()

    try await fixture.coordinator.confirm(reminderID: record.id)

    #expect(record.calendarResult == ReminderExecutionResult.failed.rawValue)
    #expect(fixture.notifications.addedIdentifierBatches.count == 1)
    #expect(record.notificationResult == ReminderExecutionResult.scheduled.rawValue)
}

@MainActor
@Test func confirmMarksDisabledOutputsNotRequested() async throws {
    let fixture = try CoordinatorFixture(
        proposal: makeProposal(notificationEnabled: false, calendarEnabled: false)
    )
    let record = try fixture.makeRecord()

    try await fixture.coordinator.confirm(reminderID: record.id)

    #expect(record.notificationResult == ReminderExecutionResult.notRequested.rawValue)
    #expect(record.calendarResult == ReminderExecutionResult.notRequested.rawValue)
    #expect(fixture.notifications.authorizationRequestCount == 0)
    #expect(fixture.calendar.authorizationRequestCount == 0)
}

@MainActor
@Test func repeatConfirmIsRejected() async throws {
    let fixture = try CoordinatorFixture()
    let record = try fixture.makeRecord()
    try await fixture.coordinator.confirm(reminderID: record.id)

    await #expect(throws: ReminderSchedulingCoordinatorError.invalidStatus(.scheduled)) {
        try await fixture.coordinator.confirm(reminderID: record.id)
    }
}

@MainActor
@Test func editCleansUpOutputsResetsExecutionAndSavesProposal() async throws {
    let fixture = try CoordinatorFixture()
    let record = try fixture.makeRecord()
    try await fixture.coordinator.confirm(reminderID: record.id)
    let edited = makeProposal(title: "Edited")

    try fixture.coordinator.edit(reminderID: record.id, proposal: edited)

    #expect(fixture.calendar.removedReferences == [
        CalendarEventReference(eventIdentifier: "event-1", externalIdentifier: "external-1")
    ])
    #expect(fixture.notifications.removedIdentifierBatches == [fixture.expectedNotificationIDs])
    #expect(record.status == ReminderProposalStatus.pendingConfirmation.rawValue)
    #expect(try fixture.repository.reminderProposal(from: record) == edited)
}

@MainActor
@Test func cancelCleansUpOutputsAndPersistsCancelledStatus() async throws {
    let fixture = try CoordinatorFixture()
    let record = try fixture.makeRecord()
    try await fixture.coordinator.confirm(reminderID: record.id)

    try fixture.coordinator.cancel(reminderID: record.id)

    #expect(fixture.notifications.removedIdentifierBatches == [fixture.expectedNotificationIDs])
    #expect(record.status == ReminderProposalStatus.cancelled.rawValue)
}

@MainActor
@Test func calendarCleanupFailureLeavesNotificationsAndDatabaseUntouched() async throws {
    let fixture = try CoordinatorFixture()
    let record = try fixture.makeRecord()
    try await fixture.coordinator.confirm(reminderID: record.id)
    fixture.calendar.removeError = FixtureError.failed

    #expect(throws: FixtureError.failed) {
        try fixture.coordinator.cancel(reminderID: record.id)
    }

    #expect(fixture.notifications.removedIdentifierBatches.isEmpty)
    #expect(record.status == ReminderProposalStatus.scheduled.rawValue)
    #expect(record.notificationIdentifiers == fixture.expectedNotificationIDs)
}

@MainActor
@Test func editRejectsExecutingReminderWithoutCleanupOrDatabaseMutation() throws {
    let fixture = try CoordinatorFixture()
    let record = try fixture.makeExecutingRecord()

    #expect(throws: ReminderSchedulingCoordinatorError.invalidStatus(.executing)) {
        try fixture.coordinator.edit(
            reminderID: record.id,
            proposal: makeProposal(title: "Edited")
        )
    }

    #expect(fixture.calendar.removedReferences.isEmpty)
    #expect(fixture.notifications.removedIdentifierBatches.isEmpty)
    #expect(record.status == ReminderProposalStatus.executing.rawValue)
    #expect(record.notificationIdentifiers == fixture.expectedNotificationIDs)
    #expect(record.calendarEventIdentifier == "event-1")
}

@MainActor
@Test func cancelRejectsExecutingReminderWithoutCleanupOrDatabaseMutation() throws {
    let fixture = try CoordinatorFixture()
    let record = try fixture.makeExecutingRecord()

    #expect(throws: ReminderSchedulingCoordinatorError.invalidStatus(.executing)) {
        try fixture.coordinator.cancel(reminderID: record.id)
    }

    #expect(fixture.calendar.removedReferences.isEmpty)
    #expect(fixture.notifications.removedIdentifierBatches.isEmpty)
    #expect(record.status == ReminderProposalStatus.executing.rawValue)
    #expect(record.notificationIdentifiers == fixture.expectedNotificationIDs)
    #expect(record.calendarEventIdentifier == "event-1")
}

@MainActor
private final class CoordinatorFixture {
    let repository: DiaryRepository
    let notifications = NotificationClientSpy()
    let calendar = CalendarClientSpy()
    let proposal: ReminderProposal
    let coordinator: ReminderSchedulingCoordinator

    var expectedNotificationIDs: [String] {
        requests.map(\.identifier)
    }

    private let requests = ["notification-1", "notification-2"].map(makeNotificationRequest)

    init(proposal: ReminderProposal = makeProposal()) throws {
        let container = try DiaryModelContainerFactory.make(inMemory: true)
        let requests = self.requests
        retainedContainers.append(container)
        repository = DiaryRepository(context: container.mainContext)
        self.proposal = proposal
        coordinator = ReminderSchedulingCoordinator(
            repository: repository,
            notificationClient: notifications,
            calendarClient: calendar,
            requestFactory: { _, _, _ in requests },
            now: { Date(timeIntervalSince1970: 1_000) }
        )
    }

    func makeRecord() throws -> ReminderRecord {
        try repository.createReminderProposal(proposal, sourceMessageID: nil)
    }

    func makeExecutingRecord() throws -> ReminderRecord {
        let record = try makeRecord()
        try repository.updateReminderExecution(
            id: record.id,
            status: .executing,
            notificationResult: .pending,
            calendarResult: .pending,
            notificationIdentifiers: expectedNotificationIDs,
            calendarEventIdentifier: "event-1",
            calendarExternalIdentifier: "external-1"
        )
        return record
    }
}

@MainActor private var retainedContainers: [ModelContainer] = []

@MainActor
private final class NotificationClientSpy: ReminderNotificationClient {
    var authorizationGranted = true
    var requestAuthorizationError: Error?
    var authorizationRequestCount = 0
    var addedIdentifierBatches: [[String]] = []
    var removedIdentifierBatches: [[String]] = []

    func requestAuthorization() async throws -> Bool {
        authorizationRequestCount += 1
        if let requestAuthorizationError {
            throw requestAuthorizationError
        }
        return authorizationGranted
    }

    func add(_ requests: [UNNotificationRequest]) async throws {
        addedIdentifierBatches.append(requests.map(\.identifier))
    }

    func removePendingRequests(withIdentifiers identifiers: [String]) {
        removedIdentifierBatches.append(identifiers)
    }
}

@MainActor
private final class CalendarClientSpy: CalendarClient {
    var authorizationGranted = true
    var requestAuthorizationError: Error?
    var removeError: Error?
    var authorizationRequestCount = 0
    var createEventCount = 0
    var removedReferences: [CalendarEventReference] = []

    func requestFullAccess() async throws -> Bool {
        authorizationRequestCount += 1
        if let requestAuthorizationError {
            throw requestAuthorizationError
        }
        return authorizationGranted
    }

    func busyIntervals(in searchWindow: DateInterval) async throws -> [DateInterval] {
        []
    }

    func createEvent(for proposal: ReminderProposal) async throws -> CalendarEventReference {
        createEventCount += 1
        return CalendarEventReference(eventIdentifier: "event-1", externalIdentifier: "external-1")
    }

    func removeEvent(reference: CalendarEventReference) throws {
        removedReferences.append(reference)
        if let removeError {
            throw removeError
        }
    }
}

private enum FixtureError: Error {
    case failed
}

private func makeProposal(
    title: String = "Plan week",
    notificationEnabled: Bool = true,
    calendarEnabled: Bool = true
) -> ReminderProposal {
    ReminderProposal(
        title: title,
        notes: "Bring notes",
        start: Date(timeIntervalSince1970: 2_000),
        durationMinutes: 30,
        recurrence: .once,
        schedulingMode: .fixed,
        searchWindow: nil,
        notificationEnabled: notificationEnabled,
        calendarEnabled: calendarEnabled
    )
}

private func makeNotificationRequest(identifier: String) -> UNNotificationRequest {
    UNNotificationRequest(identifier: identifier, content: UNNotificationContent(), trigger: nil)
}
