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
    #expect(fixture.cleanupJournal.entries[record.id] == nil)
}

@MainActor
@Test func confirmSchedulesAlarmBetweenNotificationsAndCalendarAndPersistsIdentifiers() async throws {
    let fixture = try CoordinatorFixture(
        proposal: makeProposal(alarmEnabled: true)
    )
    let record = try fixture.makeRecord()

    try await fixture.coordinator.confirm(reminderID: record.id)

    #expect(fixture.alarms.authorizationRequestCount == 1)
    #expect(fixture.alarms.scheduledReminderIDs == [record.id])
    #expect(fixture.operationLog.values == ["notifications", "alarms", "calendar"])
    #expect(record.alarmResult == ReminderExecutionResult.scheduled.rawValue)
    #expect(record.alarmIdentifiers == fixture.expectedAlarmIDs)
}

@MainActor
@Test func confirmSkipsAlarmClientWhenAlarmIsDisabled() async throws {
    let fixture = try CoordinatorFixture()
    let record = try fixture.makeRecord()

    try await fixture.coordinator.confirm(reminderID: record.id)

    #expect(fixture.alarms.authorizationRequestCount == 0)
    #expect(fixture.alarms.scheduledReminderIDs.isEmpty)
    #expect(record.alarmResult == ReminderExecutionResult.notRequested.rawValue)
    #expect(record.alarmIdentifiers.isEmpty)
}

@MainActor
@Test func confirmRecordsOrdinaryAlarmFailureAndContinuesCalendar() async throws {
    let fixture = try CoordinatorFixture(
        proposal: makeProposal(alarmEnabled: true)
    )
    fixture.alarms.scheduleError = FixtureError.failed
    let record = try fixture.makeRecord()

    try await fixture.coordinator.confirm(reminderID: record.id)

    #expect(record.alarmResult == ReminderExecutionResult.failed.rawValue)
    #expect(fixture.calendar.createEventCount == 1)
    #expect(record.calendarResult == ReminderExecutionResult.created.rawValue)
}

@MainActor
@Test func alarmRollbackFailurePreservesRecoveryHandles() async throws {
    let fixture = try CoordinatorFixture(
        proposal: makeProposal(
            notificationEnabled: false,
            alarmEnabled: true,
            calendarEnabled: false
        )
    )
    let rollbackIDs = [
        "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE",
        "11111111-2222-3333-4444-555555555555",
    ]
    fixture.alarms.scheduleError = AlarmClientError.rollbackFailed(
        rollbackIDs
    )
    let record = try fixture.makeRecord()

    await #expect(throws: ReminderSchedulingCoordinatorError.cleanupFailed) {
        try await fixture.coordinator.confirm(reminderID: record.id)
    }

    #expect(record.status == ReminderProposalStatus.executing.rawValue)
    #expect(record.alarmIdentifiers == rollbackIDs)
    #expect(fixture.cleanupJournal.entries[record.id] == ReminderCleanupJournalEntry(
        calendarReference: nil,
        notificationIdentifiers: [],
        alarmIdentifiers: rollbackIDs
    ))
}

@MainActor
@Test func unavailableAlarmClientRequirementIsSurfacedWithoutNotificationFallback() async throws {
    let fixture = try CoordinatorFixture(
        proposal: makeProposal(
            notificationEnabled: false,
            alarmEnabled: true,
            calendarEnabled: false
        ),
        alarmClient: UnavailableAlarmClient()
    )
    let record = try fixture.makeRecord()

    await #expect(throws: AlarmClientError.alarmRequiresIOS26) {
        try await fixture.coordinator.confirm(reminderID: record.id)
    }

    #expect(fixture.notifications.authorizationRequestCount == 0)
    #expect(fixture.notifications.addedIdentifierBatches.isEmpty)
    #expect(record.status == ReminderProposalStatus.pendingConfirmation.rawValue)
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
    let fixture = try CoordinatorFixture(proposal: makeProposal(alarmEnabled: true))
    let record = try fixture.makeRecord()
    try await fixture.coordinator.confirm(reminderID: record.id)
    let edited = makeProposal(title: "Edited")

    try fixture.coordinator.edit(reminderID: record.id, proposal: edited)

    #expect(fixture.calendar.removedReferences == [
        CalendarEventReference(eventIdentifier: "event-1", externalIdentifier: "external-1")
    ])
    #expect(fixture.notifications.removedIdentifierBatches == [fixture.expectedNotificationIDs])
    #expect(fixture.alarms.removedIdentifierBatches == [fixture.expectedAlarmIDs])
    #expect(record.status == ReminderProposalStatus.pendingConfirmation.rawValue)
    #expect(try fixture.repository.reminderProposal(from: record) == edited)
}

@MainActor
@Test func editRejectsInvalidProposalBeforeCleaningUpExistingOutputs() async throws {
    let fixture = try CoordinatorFixture()
    let record = try fixture.makeRecord()
    try await fixture.coordinator.confirm(reminderID: record.id)

    #expect(throws: ReminderProposalValidationError.emptyTitle) {
        try fixture.coordinator.edit(
            reminderID: record.id,
            proposal: makeProposal(title: "")
        )
    }

    #expect(fixture.calendar.removedReferences.isEmpty)
    #expect(fixture.notifications.removedIdentifierBatches.isEmpty)
    #expect(record.status == ReminderProposalStatus.scheduled.rawValue)
    #expect(record.notificationIdentifiers == fixture.expectedNotificationIDs)
}

@MainActor
@Test func cancelCleansUpOutputsAndPersistsCancelledStatus() async throws {
    let fixture = try CoordinatorFixture(proposal: makeProposal(alarmEnabled: true))
    let record = try fixture.makeRecord()
    try await fixture.coordinator.confirm(reminderID: record.id)

    try fixture.coordinator.cancel(reminderID: record.id)

    #expect(fixture.notifications.removedIdentifierBatches == [fixture.expectedNotificationIDs])
    #expect(fixture.alarms.removedIdentifierBatches == [fixture.expectedAlarmIDs])
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
@Test func notificationAuthorizationCancellationStopsCalendarAndResetsExecution() async throws {
    let fixture = try CoordinatorFixture()
    fixture.notifications.requestAuthorizationError = CancellationError()
    let record = try fixture.makeRecord()

    await #expect(throws: CancellationError.self) {
        try await fixture.coordinator.confirm(reminderID: record.id)
    }

    #expect(fixture.calendar.authorizationRequestCount == 0)
    #expect(record.status == ReminderProposalStatus.pendingConfirmation.rawValue)
}

@MainActor
@Test func calendarAuthorizationCancellationCleansScheduledNotificationsAndResetsExecution() async throws {
    let fixture = try CoordinatorFixture()
    fixture.calendar.requestAuthorizationError = CancellationError()
    let record = try fixture.makeRecord()

    await #expect(throws: CancellationError.self) {
        try await fixture.coordinator.confirm(reminderID: record.id)
    }

    #expect(fixture.notifications.removedIdentifierBatches == [fixture.expectedNotificationIDs])
    #expect(record.status == ReminderProposalStatus.pendingConfirmation.rawValue)
    #expect(record.notificationIdentifiers.isEmpty)
}

@MainActor
@Test func recoverInterruptedExecutionCleansPersistedOutputsAndResetsExecution() throws {
    let fixture = try CoordinatorFixture()
    let record = try fixture.makeExecutingRecord()

    try fixture.coordinator.recoverInterruptedExecution(reminderID: record.id)

    #expect(fixture.calendar.removedReferences == [
        CalendarEventReference(eventIdentifier: "event-1", externalIdentifier: "external-1")
    ])
    #expect(fixture.notifications.removedIdentifierBatches == [fixture.expectedNotificationIDs])
    #expect(record.status == ReminderProposalStatus.pendingConfirmation.rawValue)
    #expect(record.notificationIdentifiers.isEmpty)
}

@MainActor
@Test func recoverInterruptedExecutionUsesJournalWhenDatabaseLacksHandles() throws {
    let fixture = try CoordinatorFixture()
    let record = try fixture.makeRecord()
    try fixture.repository.updateReminderExecution(
        id: record.id,
        status: .executing,
        notificationResult: .pending,
        calendarResult: .pending,
        notificationIdentifiers: [],
        calendarEventIdentifier: nil,
        calendarExternalIdentifier: nil
    )
    let reference = CalendarEventReference(
        eventIdentifier: "journal-event",
        externalIdentifier: "journal-external"
    )
    fixture.cleanupJournal.entries[record.id] = ReminderCleanupJournalEntry(
        calendarReference: reference,
        notificationIdentifiers: ["journal-notification"],
        alarmIdentifiers: ["journal-alarm"]
    )

    try fixture.coordinator.recoverInterruptedExecution(reminderID: record.id)

    #expect(fixture.calendar.removedReferences == [reference])
    #expect(fixture.notifications.removedIdentifierBatches == [["journal-notification"]])
    #expect(fixture.alarms.removedIdentifierBatches == [["journal-alarm"]])
    #expect(record.status == ReminderProposalStatus.pendingConfirmation.rawValue)
    #expect(fixture.cleanupJournal.entries[record.id] == nil)
}

@MainActor
@Test func suspendedConfirmRejectsReentrantEditAndCancelWithoutCleanup() async throws {
    let fixture = try CoordinatorFixture()
    fixture.notifications.suspendAuthorization()
    let record = try fixture.makeRecord()
    let confirmTask = Task {
        try await fixture.coordinator.confirm(reminderID: record.id)
    }
    await fixture.notifications.waitUntilAuthorizationRequested()

    #expect(throws: ReminderSchedulingCoordinatorError.invalidStatus(.executing)) {
        try fixture.coordinator.edit(reminderID: record.id, proposal: makeProposal(title: "Edited"))
    }
    #expect(throws: ReminderSchedulingCoordinatorError.invalidStatus(.executing)) {
        try fixture.coordinator.cancel(reminderID: record.id)
    }
    #expect(fixture.calendar.removedReferences.isEmpty)
    #expect(fixture.notifications.removedIdentifierBatches.isEmpty)

    fixture.notifications.resumeAuthorization()
    try await confirmTask.value
}

@MainActor
@Test func notificationPersistenceFailureRollsBackAddedRequestsAndResetsExecution() async throws {
    let fixture = try CoordinatorFixture()
    let persistence = FailingReminderPersistence(
        repository: fixture.repository,
        failUpdateCall: 2
    )
    let coordinator = fixture.makeCoordinator(repository: persistence)
    let record = try fixture.makeRecord()

    await #expect(throws: FixtureError.persistenceFailed) {
        try await coordinator.confirm(reminderID: record.id)
    }

    #expect(fixture.notifications.removedIdentifierBatches == [fixture.expectedNotificationIDs])
    #expect(fixture.calendar.authorizationRequestCount == 0)
    #expect(record.status == ReminderProposalStatus.pendingConfirmation.rawValue)
    #expect(record.notificationIdentifiers.isEmpty)
}

@MainActor
@Test func alarmPersistenceFailureRollsBackAddedAlarmAndNotificationOutputs() async throws {
    let fixture = try CoordinatorFixture(proposal: makeProposal(alarmEnabled: true))
    let persistence = FailingReminderPersistence(
        repository: fixture.repository,
        failUpdateCall: 3
    )
    let coordinator = fixture.makeCoordinator(repository: persistence)
    let record = try fixture.makeRecord()

    await #expect(throws: FixtureError.persistenceFailed) {
        try await coordinator.confirm(reminderID: record.id)
    }

    #expect(fixture.alarms.removedIdentifierBatches == [fixture.expectedAlarmIDs])
    #expect(fixture.notifications.removedIdentifierBatches == [fixture.expectedNotificationIDs])
    #expect(record.status == ReminderProposalStatus.pendingConfirmation.rawValue)
    #expect(record.alarmIdentifiers.isEmpty)
}

@MainActor
@Test func notificationJournalFailureRollsBackAddedRequestsAndContinuesCalendar() async throws {
    let fixture = try CoordinatorFixture()
    fixture.cleanupJournal.failSaveCalls = [1]
    let record = try fixture.makeRecord()

    try await fixture.coordinator.confirm(reminderID: record.id)

    #expect(fixture.notifications.removedIdentifierBatches == [fixture.expectedNotificationIDs])
    #expect(fixture.calendar.authorizationRequestCount == 1)
    #expect(record.notificationResult == ReminderExecutionResult.failed.rawValue)
    #expect(record.calendarResult == ReminderExecutionResult.created.rawValue)
}

@MainActor
@Test func alarmJournalFailureAndRemovalFailureSurfacesCleanupFailedWithRecoveryHandles() async throws {
    let fixture = try CoordinatorFixture(
        proposal: makeProposal(
            notificationEnabled: false,
            alarmEnabled: true,
            calendarEnabled: false
        )
    )
    fixture.cleanupJournal.failSaveCalls = [1]
    fixture.alarms.failRemoveCalls = [1]
    let record = try fixture.makeRecord()

    await #expect(throws: ReminderSchedulingCoordinatorError.cleanupFailed) {
        try await fixture.coordinator.confirm(reminderID: record.id)
    }

    #expect(record.status == ReminderProposalStatus.executing.rawValue)
    #expect(record.alarmIdentifiers == fixture.expectedAlarmIDs)
    #expect(fixture.cleanupJournal.entries[record.id] == ReminderCleanupJournalEntry(
        calendarReference: nil,
        notificationIdentifiers: [],
        alarmIdentifiers: fixture.expectedAlarmIDs
    ))
}

@MainActor
@Test func calendarPersistenceFailureRollsBackAllCreatedOutputsAndResetsExecution() async throws {
    let fixture = try CoordinatorFixture()
    let persistence = FailingReminderPersistence(
        repository: fixture.repository,
        failUpdateCall: 3
    )
    let coordinator = fixture.makeCoordinator(repository: persistence)
    let record = try fixture.makeRecord()

    await #expect(throws: FixtureError.persistenceFailed) {
        try await coordinator.confirm(reminderID: record.id)
    }

    #expect(fixture.calendar.removedReferences == [
        CalendarEventReference(eventIdentifier: "event-1", externalIdentifier: "external-1")
    ])
    #expect(fixture.notifications.removedIdentifierBatches == [fixture.expectedNotificationIDs])
    #expect(record.status == ReminderProposalStatus.pendingConfirmation.rawValue)
    #expect(record.notificationIdentifiers.isEmpty)
    #expect(record.calendarEventIdentifier == nil)
}

@MainActor
@Test func calendarJournalFailureRemovesCreatedEventAndKeepsScheduledNotifications() async throws {
    let fixture = try CoordinatorFixture()
    fixture.cleanupJournal.failSaveCalls = [2]
    let record = try fixture.makeRecord()

    try await fixture.coordinator.confirm(reminderID: record.id)

    #expect(fixture.calendar.removedReferences == [
        CalendarEventReference(eventIdentifier: "event-1", externalIdentifier: "external-1")
    ])
    #expect(fixture.notifications.removedIdentifierBatches.isEmpty)
    #expect(record.notificationResult == ReminderExecutionResult.scheduled.rawValue)
    #expect(record.calendarResult == ReminderExecutionResult.failed.rawValue)
    #expect(record.calendarEventIdentifier == nil)
}

@MainActor
@Test func cancelledTaskAfterCalendarAuthorizationStopsCreationAndCleansNotifications() async throws {
    let fixture = try CoordinatorFixture()
    fixture.calendar.suspendAuthorization()
    let record = try fixture.makeRecord()
    let confirmTask = Task {
        try await fixture.coordinator.confirm(reminderID: record.id)
    }
    await fixture.calendar.waitUntilAuthorizationRequested()

    confirmTask.cancel()
    fixture.calendar.resumeAuthorization()

    await #expect(throws: CancellationError.self) {
        try await confirmTask.value
    }
    #expect(fixture.calendar.createEventCount == 0)
    #expect(fixture.notifications.removedIdentifierBatches == [fixture.expectedNotificationIDs])
    #expect(record.status == ReminderProposalStatus.pendingConfirmation.rawValue)
    #expect(record.notificationIdentifiers.isEmpty)
}

@MainActor
@Test func calendarCleanupFailureDuringCompensationPreservesRecoveryHandles() async throws {
    let fixture = try CoordinatorFixture()
    fixture.calendar.removeError = FixtureError.failed
    let persistence = FailingReminderPersistence(
        repository: fixture.repository,
        failUpdateCall: 3
    )
    let coordinator = fixture.makeCoordinator(repository: persistence)
    let record = try fixture.makeRecord()

    await #expect(throws: ReminderSchedulingCoordinatorError.cleanupFailed) {
        try await coordinator.confirm(reminderID: record.id)
    }

    #expect(fixture.notifications.removedIdentifierBatches == [fixture.expectedNotificationIDs])
    #expect(record.status == ReminderProposalStatus.executing.rawValue)
    #expect(record.notificationIdentifiers == fixture.expectedNotificationIDs)
    #expect(record.calendarEventIdentifier == "event-1")
    #expect(record.calendarExternalIdentifier == "external-1")
    #expect(fixture.cleanupJournal.entries[record.id] == ReminderCleanupJournalEntry(
        calendarReference: CalendarEventReference(
            eventIdentifier: "event-1",
            externalIdentifier: "external-1"
        ),
        notificationIdentifiers: fixture.expectedNotificationIDs
    ))
}

@MainActor
@Test func sustainedPersistenceFailureAndCalendarCleanupFailureKeepsJournalHandles() async throws {
    let fixture = try CoordinatorFixture()
    fixture.calendar.removeError = FixtureError.failed
    let persistence = FailingReminderPersistence(
        repository: fixture.repository,
        failUpdateCalls: [3, 4]
    )
    let coordinator = fixture.makeCoordinator(repository: persistence)
    let record = try fixture.makeRecord()

    await #expect(throws: ReminderSchedulingCoordinatorError.cleanupFailed) {
        try await coordinator.confirm(reminderID: record.id)
    }

    #expect(record.status == ReminderProposalStatus.executing.rawValue)
    #expect(fixture.cleanupJournal.entries[record.id] == ReminderCleanupJournalEntry(
        calendarReference: CalendarEventReference(
            eventIdentifier: "event-1",
            externalIdentifier: "external-1"
        ),
        notificationIdentifiers: fixture.expectedNotificationIDs
    ))
}

@MainActor
@Test func recoverInterruptedExecutionCleanupFailurePreservesRecoveryHandles() throws {
    let fixture = try CoordinatorFixture()
    let record = try fixture.makeExecutingRecord()
    fixture.calendar.removeError = FixtureError.failed

    #expect(throws: FixtureError.failed) {
        try fixture.coordinator.recoverInterruptedExecution(reminderID: record.id)
    }

    #expect(fixture.notifications.removedIdentifierBatches.isEmpty)
    #expect(record.status == ReminderProposalStatus.executing.rawValue)
    #expect(record.notificationIdentifiers == fixture.expectedNotificationIDs)
    #expect(record.calendarEventIdentifier == "event-1")
    #expect(fixture.cleanupJournal.entries[record.id] == ReminderCleanupJournalEntry(
        calendarReference: CalendarEventReference(
            eventIdentifier: "event-1",
            externalIdentifier: "external-1"
        ),
        notificationIdentifiers: fixture.expectedNotificationIDs
    ))
}

@MainActor
@Test func recoverInterruptedExecutionRetriesIdempotentAlarmRemoval() throws {
    let fixture = try CoordinatorFixture()
    let record = try fixture.makeRecord()
    try fixture.repository.updateReminderExecution(
        id: record.id,
        status: .executing,
        notificationResult: .notRequested,
        alarmResult: .pending,
        calendarResult: .notRequested,
        notificationIdentifiers: [],
        alarmIdentifiers: ["alarm-retry"],
        calendarEventIdentifier: nil,
        calendarExternalIdentifier: nil
    )
    fixture.alarms.failRemoveCalls = [1]

    #expect(throws: FixtureError.failed) {
        try fixture.coordinator.recoverInterruptedExecution(reminderID: record.id)
    }
    try fixture.coordinator.recoverInterruptedExecution(reminderID: record.id)

    #expect(fixture.alarms.removedIdentifierBatches == [
        ["alarm-retry"],
        ["alarm-retry"],
    ])
    #expect(record.status == ReminderProposalStatus.pendingConfirmation.rawValue)
    #expect(record.alarmIdentifiers.isEmpty)
}

@MainActor
private final class CoordinatorFixture {
    let repository: DiaryRepository
    let notifications = NotificationClientSpy()
    let alarms = AlarmClientSpy()
    let calendar = CalendarClientSpy()
    let cleanupJournal = CleanupJournalSpy()
    let operationLog = OperationLog()
    let proposal: ReminderProposal
    let coordinator: ReminderSchedulingCoordinator

    var expectedNotificationIDs: [String] {
        requests.map(\.identifier)
    }

    var expectedAlarmIDs: [String] {
        alarms.scheduledIdentifiers
    }

    private let requests = ["notification-1", "notification-2"].map(makeNotificationRequest)

    init(
        proposal: ReminderProposal = makeProposal(),
        alarmClient: (any AlarmClient)? = nil
    ) throws {
        let container = try DiaryModelContainerFactory.make(inMemory: true)
        let requests = self.requests
        retainedContainers.append(container)
        repository = DiaryRepository(context: container.mainContext)
        self.proposal = proposal
        notifications.onAdd = { [operationLog] in operationLog.values.append("notifications") }
        alarms.onSchedule = { [operationLog] in operationLog.values.append("alarms") }
        calendar.onCreate = { [operationLog] in operationLog.values.append("calendar") }
        coordinator = ReminderSchedulingCoordinator(
            repository: repository,
            notificationClient: notifications,
            alarmClient: alarmClient ?? alarms,
            calendarClient: calendar,
            cleanupJournal: cleanupJournal,
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

    func makeCoordinator(
        repository: any ReminderPersistence
    ) -> ReminderSchedulingCoordinator {
        let requests = self.requests
        return ReminderSchedulingCoordinator(
            repository: repository,
            notificationClient: notifications,
            alarmClient: alarms,
            calendarClient: calendar,
            cleanupJournal: cleanupJournal,
            requestFactory: { _, _, _ in requests },
            now: { Date(timeIntervalSince1970: 1_000) }
        )
    }
}

@MainActor private var retainedContainers: [ModelContainer] = []

@MainActor
private final class OperationLog {
    var values: [String] = []
}

@MainActor
private final class CleanupJournalSpy: ReminderCleanupJournaling {
    var entries: [UUID: ReminderCleanupJournalEntry] = [:]
    var failSaveCalls: Set<Int> = []
    private var saveCallCount = 0

    func save(reminderID: UUID, entry: ReminderCleanupJournalEntry) throws {
        saveCallCount += 1
        guard !failSaveCalls.contains(saveCallCount) else {
            throw FixtureError.failed
        }
        entries[reminderID] = entry
    }

    func load(reminderID: UUID) throws -> ReminderCleanupJournalEntry? {
        entries[reminderID]
    }

    func remove(reminderID: UUID) throws {
        entries.removeValue(forKey: reminderID)
    }
}

@MainActor
private final class NotificationClientSpy: ReminderNotificationClient {
    var authorizationGranted = true
    var requestAuthorizationError: Error?
    var authorizationRequestCount = 0
    var addedIdentifierBatches: [[String]] = []
    var removedIdentifierBatches: [[String]] = []
    var onAdd: () -> Void = {}
    private var shouldSuspendAuthorization = false
    private var authorizationContinuation: CheckedContinuation<Void, Never>?
    private var requestWaiters: [CheckedContinuation<Void, Never>] = []

    func requestAuthorization() async throws -> Bool {
        authorizationRequestCount += 1
        requestWaiters.forEach { $0.resume() }
        requestWaiters = []
        if shouldSuspendAuthorization {
            await withCheckedContinuation { continuation in
                authorizationContinuation = continuation
            }
        }
        if let requestAuthorizationError {
            throw requestAuthorizationError
        }
        return authorizationGranted
    }

    func add(_ requests: [UNNotificationRequest]) async throws {
        onAdd()
        addedIdentifierBatches.append(requests.map(\.identifier))
    }

    func removePendingRequests(withIdentifiers identifiers: [String]) {
        removedIdentifierBatches.append(identifiers)
    }

    func suspendAuthorization() {
        shouldSuspendAuthorization = true
    }

    func waitUntilAuthorizationRequested() async {
        guard authorizationRequestCount == 0 else {
            return
        }
        await withCheckedContinuation { continuation in
            requestWaiters.append(continuation)
        }
    }

    func resumeAuthorization() {
        shouldSuspendAuthorization = false
        authorizationContinuation?.resume()
        authorizationContinuation = nil
    }
}

@MainActor
private final class AlarmClientSpy: AlarmClient {
    var authorizationGranted = true
    var scheduleError: Error?
    var authorizationRequestCount = 0
    var scheduledReminderIDs: [UUID] = []
    var removedIdentifierBatches: [[String]] = []
    var failRemoveCalls: Set<Int> = []
    var onSchedule: () -> Void = {}

    var scheduledIdentifiers: [String] {
        scheduledOccurrences.flatMap { $0 }.map(\.identifier.uuidString)
    }

    private(set) var scheduledOccurrences: [[AlarmOccurrence]] = []
    private var removeCallCount = 0

    func requestAuthorization() async throws -> Bool {
        authorizationRequestCount += 1
        return authorizationGranted
    }

    func schedule(
        reminderID: UUID,
        proposal: ReminderProposal,
        occurrences: [AlarmOccurrence]
    ) async throws {
        onSchedule()
        scheduledReminderIDs.append(reminderID)
        if let scheduleError {
            throw scheduleError
        }
        scheduledOccurrences.append(occurrences)
    }

    func remove(ids: [String]) throws {
        removeCallCount += 1
        removedIdentifierBatches.append(ids)
        guard !failRemoveCalls.contains(removeCallCount) else {
            throw FixtureError.failed
        }
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
    var onCreate: () -> Void = {}
    private var shouldSuspendAuthorization = false
    private var authorizationContinuation: CheckedContinuation<Void, Never>?
    private var requestWaiters: [CheckedContinuation<Void, Never>] = []

    func requestFullAccess() async throws -> Bool {
        authorizationRequestCount += 1
        requestWaiters.forEach { $0.resume() }
        requestWaiters = []
        if shouldSuspendAuthorization {
            await withCheckedContinuation { continuation in
                authorizationContinuation = continuation
            }
        }
        if let requestAuthorizationError {
            throw requestAuthorizationError
        }
        return authorizationGranted
    }

    func busyIntervals(in searchWindow: DateInterval) async throws -> [DateInterval] {
        []
    }

    func createEvent(for proposal: ReminderProposal) async throws -> CalendarEventReference {
        onCreate()
        createEventCount += 1
        return CalendarEventReference(eventIdentifier: "event-1", externalIdentifier: "external-1")
    }

    func removeEvent(reference: CalendarEventReference) throws {
        removedReferences.append(reference)
        if let removeError {
            throw removeError
        }
    }

    func suspendAuthorization() {
        shouldSuspendAuthorization = true
    }

    func waitUntilAuthorizationRequested() async {
        guard authorizationRequestCount == 0 else {
            return
        }
        await withCheckedContinuation { continuation in
            requestWaiters.append(continuation)
        }
    }

    func resumeAuthorization() {
        shouldSuspendAuthorization = false
        authorizationContinuation?.resume()
        authorizationContinuation = nil
    }
}

private enum FixtureError: Error {
    case failed
    case persistenceFailed
}

@MainActor
private final class FailingReminderPersistence: ReminderPersistence {
    private let repository: DiaryRepository
    private let failUpdateCalls: Set<Int>
    private var updateCallCount = 0

    init(repository: DiaryRepository, failUpdateCall: Int) {
        self.repository = repository
        failUpdateCalls = [failUpdateCall]
    }

    init(repository: DiaryRepository, failUpdateCalls: Set<Int>) {
        self.repository = repository
        self.failUpdateCalls = failUpdateCalls
    }

    func reminder(id: UUID) throws -> ReminderRecord {
        try repository.reminder(id: id)
    }

    func reminderProposal(from record: ReminderRecord) throws -> ReminderProposal {
        try repository.reminderProposal(from: record)
    }

    func updateReminderExecution(
        id: UUID,
        status: ReminderProposalStatus,
        notificationResult: ReminderExecutionResult,
        alarmResult: ReminderExecutionResult,
        calendarResult: ReminderExecutionResult,
        notificationIdentifiers: [String],
        alarmIdentifiers: [String],
        calendarEventIdentifier: String?,
        calendarExternalIdentifier: String?
    ) throws {
        updateCallCount += 1
        guard !failUpdateCalls.contains(updateCallCount) else {
            throw FixtureError.persistenceFailed
        }
        try repository.updateReminderExecution(
            id: id,
            status: status,
            notificationResult: notificationResult,
            alarmResult: alarmResult,
            calendarResult: calendarResult,
            notificationIdentifiers: notificationIdentifiers,
            alarmIdentifiers: alarmIdentifiers,
            calendarEventIdentifier: calendarEventIdentifier,
            calendarExternalIdentifier: calendarExternalIdentifier
        )
    }

    func resetReminderExecution(id: UUID) throws {
        try repository.resetReminderExecution(id: id)
    }

    func updateReminderProposal(id: UUID, proposal: ReminderProposal) throws {
        try repository.updateReminderProposal(id: id, proposal: proposal)
    }

    func cancelReminder(id: UUID) throws {
        try repository.cancelReminder(id: id)
    }
}

private func makeProposal(
    title: String = "Plan week",
    notificationEnabled: Bool = true,
    alarmEnabled: Bool = false,
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
        alarmEnabled: alarmEnabled,
        calendarEnabled: calendarEnabled
    )
}

private func makeNotificationRequest(identifier: String) -> UNNotificationRequest {
    UNNotificationRequest(identifier: identifier, content: UNNotificationContent(), trigger: nil)
}
