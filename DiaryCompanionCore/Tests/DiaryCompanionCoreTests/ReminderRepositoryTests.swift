import Foundation
import SwiftData
import Testing
@testable import DiaryCompanionCore

@MainActor
@Test func reminderProposalRoundTripsWithDefaultsAndSourceMessage() throws {
    let repository = try makeReminderRepository()
    let sourceMessageID = UUID()
    let proposal = makeFindFreeTimeProposal()

    let created = try repository.createReminderProposal(
        proposal,
        sourceMessageID: sourceMessageID
    )
    let fetched = try #require(repository.fetchReminders().first)

    #expect(fetched.id == created.id)
    #expect(fetched.sourceMessageID == sourceMessageID)
    #expect(fetched.status == ReminderProposalStatus.pendingConfirmation.rawValue)
    #expect(fetched.notificationResult == ReminderExecutionResult.notRequested.rawValue)
    #expect(fetched.calendarResult == ReminderExecutionResult.notRequested.rawValue)
    #expect(fetched.notificationIdentifiers.isEmpty)
    #expect(fetched.calendarEventIdentifier == nil)
    #expect(fetched.calendarExternalIdentifier == nil)
    #expect(try repository.reminderProposal(from: fetched) == proposal)
}

@MainActor
@Test func reminderExecutionUpdatePersistsResultsAndIdentifiers() throws {
    let repository = try makeReminderRepository()
    let record = try repository.createReminderProposal(
        makeFindFreeTimeProposal(),
        sourceMessageID: nil
    )

    try repository.updateReminderExecution(
        id: record.id,
        status: .scheduled,
        notificationResult: .scheduled,
        calendarResult: .permissionDenied,
        notificationIdentifiers: [
            "notification-1",
            "notification-2",
            "notification-1",
        ],
        calendarEventIdentifier: "calendar-1",
        calendarExternalIdentifier: "external-1"
    )

    let fetched = try #require(repository.fetchReminders().first)
    #expect(fetched.status == ReminderProposalStatus.scheduled.rawValue)
    #expect(fetched.notificationResult == ReminderExecutionResult.scheduled.rawValue)
    #expect(fetched.calendarResult == ReminderExecutionResult.permissionDenied.rawValue)
    #expect(fetched.notificationIdentifiers == ["notification-1", "notification-2"])
    #expect(fetched.calendarEventIdentifier == "calendar-1")
    #expect(fetched.calendarExternalIdentifier == "external-1")
}

@MainActor
@Test func legacyReminderRecordReconstructsFixedOnceProposal() throws {
    let repository = try makeReminderRepository()
    let fireDate = Date(timeIntervalSince1970: 8_000)
    let record = ReminderRecord(
        title: "Legacy reminder",
        body: "Legacy body",
        fireDate: fireDate,
        isScheduled: true
    )

    let proposal = try repository.reminderProposal(from: record)

    #expect(proposal == ReminderProposal(
        title: "Legacy reminder",
        notes: "Legacy body",
        start: fireDate,
        durationMinutes: 1,
        recurrence: .once,
        schedulingMode: .fixed,
        searchWindow: nil,
        notificationEnabled: true,
        calendarEnabled: false
    ))
    #expect(record.status == ReminderProposalStatus.scheduled.rawValue)
    #expect(record.notificationResult == ReminderExecutionResult.scheduled.rawValue)
    #expect(record.calendarResult == ReminderExecutionResult.notRequested.rawValue)
}

@MainActor
@Test func unscheduledLegacyReminderRecordMapsPendingExecutionDefaults() throws {
    let repository = try makeReminderRepository()
    let record = ReminderRecord(
        title: "Legacy reminder",
        body: "Legacy body",
        fireDate: Date(timeIntervalSince1970: 8_000)
    )

    _ = try repository.reminderProposal(from: record)

    #expect(record.status == ReminderProposalStatus.pendingConfirmation.rawValue)
    #expect(record.notificationResult == ReminderExecutionResult.notRequested.rawValue)
    #expect(record.calendarResult == ReminderExecutionResult.notRequested.rawValue)
}

@MainActor
@Test func migratedLegacyReminderRecordReconstructsFromOldFields() throws {
    let repository = try makeReminderRepository()
    let fireDate = Date(timeIntervalSince1970: 8_000)
    let record = makeMigratedLegacyReminderRecord(
        fireDate: fireDate,
        isScheduled: true
    )

    let proposal = try repository.reminderProposal(from: record)

    #expect(proposal == ReminderProposal(
        title: "Migrated legacy reminder",
        notes: "Migrated legacy body",
        start: fireDate,
        durationMinutes: 1,
        recurrence: .once,
        schedulingMode: .fixed,
        searchWindow: nil,
        notificationEnabled: true,
        calendarEnabled: false
    ))
    #expect(record.status == ReminderProposalStatus.scheduled.rawValue)
    #expect(record.notificationResult == ReminderExecutionResult.scheduled.rawValue)
    #expect(record.calendarResult == ReminderExecutionResult.notRequested.rawValue)
}

@MainActor
@Test func migratedUnscheduledLegacyReminderMapsPendingExecutionDefaults() throws {
    let repository = try makeReminderRepository()
    let record = makeMigratedLegacyReminderRecord(
        fireDate: Date(timeIntervalSince1970: 8_000),
        isScheduled: false
    )

    _ = try repository.reminderProposal(from: record)

    #expect(record.status == ReminderProposalStatus.pendingConfirmation.rawValue)
    #expect(record.notificationResult == ReminderExecutionResult.notRequested.rawValue)
    #expect(record.calendarResult == ReminderExecutionResult.notRequested.rawValue)
}

@MainActor
@Test func migratedRepeatingLegacyReminderRequiresReconfirmation() throws {
    let repository = try makeReminderRepository()
    let record = makeMigratedLegacyReminderRecord(
        fireDate: Date(timeIntervalSince1970: 8_000),
        isScheduled: false
    )
    record.repeats = true

    #expect(throws: DiaryRepositoryError.legacyRepeatingReminderRequiresReconfirmation(record.id)) {
        try repository.reminderProposal(from: record)
    }
}

@MainActor
@Test func emptyRecurrenceDataWithNewProposalFieldsIsNotLegacy() throws {
    let repository = try makeReminderRepository()
    let record = makeMigratedLegacyReminderRecord(
        fireDate: Date(timeIntervalSince1970: 8_000),
        isScheduled: false
    )
    record.durationMinutes = 30

    #expect(throws: DiaryRepositoryError.invalidReminderRecurrenceData) {
        try repository.reminderProposal(from: record)
    }
}

@MainActor
@Test func reconstructingReminderRejectsPartialSearchWindow() throws {
    let repository = try makeReminderRepository()
    let record = try repository.createReminderProposal(
        makeFindFreeTimeProposal(),
        sourceMessageID: nil
    )
    record.searchWindowEnd = nil

    #expect(throws: DiaryRepositoryError.invalidReminderSearchWindow) {
        try repository.reminderProposal(from: record)
    }
}

@MainActor
@Test func reconstructingReminderValidatesPersistedDomainFields() throws {
    let repository = try makeReminderRepository()
    let record = try repository.createReminderProposal(
        makeFindFreeTimeProposal(),
        sourceMessageID: nil
    )
    record.durationMinutes = 0

    #expect(throws: ReminderProposalValidationError.invalidDurationMinutes) {
        try repository.reminderProposal(from: record)
    }
}

@MainActor
@Test func reminderProposalUpdatePersistsEditedFields() throws {
    let repository = try makeReminderRepository()
    let record = try repository.createReminderProposal(
        makeFindFreeTimeProposal(),
        sourceMessageID: nil
    )
    let edited = ReminderProposal(
        title: "Edited reminder",
        notes: "Bring a notebook",
        start: Date(timeIntervalSince1970: 5_000),
        durationMinutes: 45,
        recurrence: .daily(interval: 2, end: .occurrenceCount(4)),
        schedulingMode: .fixed,
        searchWindow: nil,
        notificationEnabled: false,
        calendarEnabled: true
    )

    try repository.updateReminderProposal(id: record.id, proposal: edited)

    let fetched = try #require(repository.fetchReminders().first)
    #expect(try repository.reminderProposal(from: fetched) == edited)
}

@MainActor
@Test func cancellingReminderPersistsCancelledStatus() throws {
    let repository = try makeReminderRepository()
    let record = try repository.createReminderProposal(
        makeFindFreeTimeProposal(),
        sourceMessageID: nil
    )

    try repository.cancelReminder(id: record.id)

    let fetched = try #require(repository.fetchReminders().first)
    #expect(fetched.status == ReminderProposalStatus.cancelled.rawValue)
}

@MainActor
@Test func resettingReminderExecutionClearsPersistedResourceState() throws {
    let repository = try makeReminderRepository()
    let record = try repository.createReminderProposal(
        makeFindFreeTimeProposal(),
        sourceMessageID: nil
    )
    try repository.updateReminderExecution(
        id: record.id,
        status: .scheduled,
        notificationResult: .scheduled,
        calendarResult: .created,
        notificationIdentifiers: ["notification-1"],
        calendarEventIdentifier: "calendar-1",
        calendarExternalIdentifier: "external-1"
    )

    try repository.resetReminderExecution(id: record.id)

    #expect(record.status == ReminderProposalStatus.pendingConfirmation.rawValue)
    #expect(record.notificationResult == ReminderExecutionResult.notRequested.rawValue)
    #expect(record.calendarResult == ReminderExecutionResult.notRequested.rawValue)
    #expect(record.notificationIdentifiers.isEmpty)
    #expect(record.calendarEventIdentifier == nil)
    #expect(record.calendarExternalIdentifier == nil)
    #expect(record.isScheduled == false)
}

@MainActor
@Test func editingReminderWithExternalResourcesRequiresExecutionReset() throws {
    let repository = try makeReminderRepository()
    let record = try repository.createReminderProposal(
        makeFindFreeTimeProposal(),
        sourceMessageID: nil
    )
    record.notificationIdentifiers = ["notification-1"]

    #expect(throws: DiaryRepositoryError.reminderRequiresExecutionReset(record.id)) {
        try repository.updateReminderProposal(
            id: record.id,
            proposal: makeFixedProposal(start: Date(timeIntervalSince1970: 5_000))
        )
    }
}

@MainActor
@Test func editingExecutingReminderRequiresExecutionReset() throws {
    let repository = try makeReminderRepository()
    let record = try repository.createReminderProposal(
        makeFindFreeTimeProposal(),
        sourceMessageID: nil
    )
    record.status = ReminderProposalStatus.executing.rawValue

    #expect(throws: DiaryRepositoryError.reminderRequiresExecutionReset(record.id)) {
        try repository.updateReminderProposal(
            id: record.id,
            proposal: makeFixedProposal(start: Date(timeIntervalSince1970: 5_000))
        )
    }
}

@MainActor
@Test func editingScheduledReminderRequiresExecutionReset() throws {
    let repository = try makeReminderRepository()
    let record = try repository.createReminderProposal(
        makeFindFreeTimeProposal(),
        sourceMessageID: nil
    )
    record.status = ReminderProposalStatus.scheduled.rawValue

    #expect(throws: DiaryRepositoryError.reminderRequiresExecutionReset(record.id)) {
        try repository.updateReminderProposal(
            id: record.id,
            proposal: makeFixedProposal(start: Date(timeIntervalSince1970: 5_000))
        )
    }
}

@MainActor
@Test func cancellingReminderWithExternalResourcesRequiresExecutionReset() throws {
    let repository = try makeReminderRepository()
    let record = try repository.createReminderProposal(
        makeFindFreeTimeProposal(),
        sourceMessageID: nil
    )
    record.calendarEventIdentifier = "calendar-1"

    #expect(throws: DiaryRepositoryError.reminderRequiresExecutionReset(record.id)) {
        try repository.cancelReminder(id: record.id)
    }
}

@MainActor
@Test func editingReminderWithCalendarExternalIdentifierRequiresExecutionReset() throws {
    let repository = try makeReminderRepository()
    let record = try repository.createReminderProposal(
        makeFindFreeTimeProposal(),
        sourceMessageID: nil
    )
    record.calendarExternalIdentifier = "external-1"

    #expect(throws: DiaryRepositoryError.reminderRequiresExecutionReset(record.id)) {
        try repository.updateReminderProposal(
            id: record.id,
            proposal: makeFixedProposal(start: Date(timeIntervalSince1970: 5_000))
        )
    }
}

@MainActor
@Test func cancellingScheduledReminderRequiresExecutionReset() throws {
    let repository = try makeReminderRepository()
    let record = try repository.createReminderProposal(
        makeFindFreeTimeProposal(),
        sourceMessageID: nil
    )
    record.status = ReminderProposalStatus.scheduled.rawValue

    #expect(throws: DiaryRepositoryError.reminderRequiresExecutionReset(record.id)) {
        try repository.cancelReminder(id: record.id)
    }
}

@MainActor
@Test func updatingUnknownReminderThrowsRepositoryError() throws {
    let repository = try makeReminderRepository()
    let id = UUID()

    #expect(throws: DiaryRepositoryError.reminderNotFound(id)) {
        try repository.cancelReminder(id: id)
    }
}

@MainActor
@Test func reconstructingReminderRejectsInvalidSchedulingMode() throws {
    let repository = try makeReminderRepository()
    let record = try repository.createReminderProposal(
        makeFindFreeTimeProposal(),
        sourceMessageID: nil
    )
    record.schedulingMode = "eventually"

    #expect(throws: DiaryRepositoryError.invalidReminderSchedulingMode("eventually")) {
        try repository.reminderProposal(from: record)
    }
}

@MainActor
@Test func reconstructingReminderRejectsInvalidStatus() throws {
    let repository = try makeReminderRepository()
    let record = try repository.createReminderProposal(
        makeFindFreeTimeProposal(),
        sourceMessageID: nil
    )
    record.status = "unknown"

    #expect(throws: DiaryRepositoryError.invalidReminderStatus("unknown")) {
        try repository.reminderProposal(from: record)
    }
}

@MainActor
@Test func fetchRemindersSortsByFirstOccurrence() throws {
    let repository = try makeReminderRepository()
    let later = makeFixedProposal(start: Date(timeIntervalSince1970: 9_000))
    let earlier = makeFixedProposal(start: Date(timeIntervalSince1970: 3_000))

    try repository.createReminderProposal(later, sourceMessageID: nil)
    try repository.createReminderProposal(earlier, sourceMessageID: nil)

    #expect(try repository.fetchReminders().map(\.title) == [
        earlier.title,
        later.title,
    ])
}

@MainActor
private func makeReminderRepository() throws -> DiaryRepository {
    let container = try DiaryModelContainerFactory.make(inMemory: true)
    retainedReminderContainers.append(container)
    return DiaryRepository(context: container.mainContext)
}

@MainActor private var retainedReminderContainers: [ModelContainer] = []

private func makeMigratedLegacyReminderRecord(
    fireDate: Date,
    isScheduled: Bool
) -> ReminderRecord {
    let record = ReminderRecord(
        title: "Migrated legacy reminder",
        body: "Migrated legacy body",
        fireDate: fireDate,
        isScheduled: isScheduled
    )
    record.notes = ""
    record.firstOccurrence = nil
    record.durationMinutes = 0
    record.recurrenceData = Data()
    record.schedulingMode = ReminderSchedulingMode.fixed.rawValue
    record.searchWindowStart = nil
    record.searchWindowEnd = nil
    record.notificationEnabled = false
    record.calendarEnabled = false
    record.status = ReminderProposalStatus.pendingConfirmation.rawValue
    record.notificationResult = ReminderExecutionResult.notRequested.rawValue
    record.calendarResult = ReminderExecutionResult.notRequested.rawValue
    record.sourceMessageID = nil
    record.notificationIdentifiers = []
    record.calendarEventIdentifier = nil
    return record
}

private func makeFindFreeTimeProposal() -> ReminderProposal {
    ReminderProposal(
        title: "Weekly planning",
        notes: "Find a quiet slot",
        start: nil,
        durationMinutes: 30,
        recurrence: .weekly(
            interval: 1,
            weekdays: [.monday, .wednesday],
            end: .occurrenceCount(6)
        ),
        schedulingMode: .findFreeTime,
        searchWindow: ReminderSearchWindow(
            start: Date(timeIntervalSince1970: 10_000),
            end: Date(timeIntervalSince1970: 20_000)
        ),
        notificationEnabled: true,
        calendarEnabled: true
    )
}

private func makeFixedProposal(start: Date) -> ReminderProposal {
    ReminderProposal(
        title: "Reminder \(start.timeIntervalSince1970)",
        notes: "",
        start: start,
        durationMinutes: 10,
        recurrence: .once,
        schedulingMode: .fixed,
        searchWindow: nil,
        notificationEnabled: true,
        calendarEnabled: false
    )
}
