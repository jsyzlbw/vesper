import Foundation
import SwiftData
import Testing
@testable import DiaryCompanionCore

@MainActor
@Test func alarmReplenisherReplacesExpiredOccurrencesAndPreservesOtherOutputs() async throws {
    let fixture = try AlarmReplenisherFixture()
    let record = try fixture.makeScheduledReminder(start: fixture.date(day: 1, hour: 9))

    try await fixture.replenisher.replenish(windowStart: fixture.date(day: 1))
    let originalIdentifiers = Set(record.alarmIdentifiers)

    #expect(fixture.alarms.scheduledOccurrenceBatches.count == 1)
    #expect(fixture.alarms.scheduledOccurrenceBatches[0].count == 60)
    #expect(record.alarmIdentifiers.count == 60)

    try await fixture.replenisher.replenish(windowStart: fixture.date(day: 20))

    #expect(fixture.alarms.scheduledOccurrenceBatches.count == 2)
    #expect(!fixture.alarms.scheduledOccurrenceBatches[1].isEmpty)
    #expect(fixture.alarms.removedIdentifierBatches == [
        originalIdentifiers.subtracting(record.alarmIdentifiers).sorted()
    ])
    #expect(record.notificationIdentifiers == ["notification-1"])
    #expect(record.calendarEventIdentifier == "event-1")
    #expect(record.calendarExternalIdentifier == "external-1")
}

@MainActor
@Test func alarmReplenisherDoesNotRescheduleExistingOccurrences() async throws {
    let fixture = try AlarmReplenisherFixture()
    _ = try fixture.makeScheduledReminder(start: fixture.date(day: 1, hour: 9))

    try await fixture.replenisher.replenish(windowStart: fixture.date(day: 1))
    try await fixture.replenisher.replenish(windowStart: fixture.date(day: 1))

    #expect(fixture.alarms.scheduledOccurrenceBatches.count == 1)
    #expect(fixture.alarms.removedIdentifierBatches.isEmpty)
}

@MainActor
private final class AlarmReplenisherFixture {
    let repository: DiaryRepository
    let alarms = ReplenisherAlarmClientSpy()
    let replenisher: ReminderAlarmReplenisher
    private let calendar: Calendar
    private let container: ModelContainer

    init() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        self.calendar = calendar
        container = try DiaryModelContainerFactory.make(inMemory: true)
        repository = DiaryRepository(context: container.mainContext)
        replenisher = ReminderAlarmReplenisher(
            repository: repository,
            alarmClient: alarms,
            occurrenceFactory: AlarmOccurrenceFactory(calendar: calendar)
        )
    }

    func makeScheduledReminder(start: Date) throws -> ReminderRecord {
        let record = try repository.createReminderProposal(
            ReminderProposal(
                title: "Review",
                notes: "",
                start: start,
                durationMinutes: 30,
                recurrence: .daily(interval: 1, end: nil),
                schedulingMode: .fixed,
                searchWindow: nil,
                notificationEnabled: true,
                alarmEnabled: true,
                calendarEnabled: true
            ),
            sourceMessageID: nil
        )
        try repository.updateReminderExecution(
            id: record.id,
            status: .scheduled,
            notificationResult: .scheduled,
            alarmResult: .scheduled,
            calendarResult: .created,
            notificationIdentifiers: ["notification-1"],
            alarmIdentifiers: [],
            calendarEventIdentifier: "event-1",
            calendarExternalIdentifier: "external-1"
        )
        return record
    }

    func date(day: Int, hour: Int = 0) -> Date {
        calendar.date(
            from: DateComponents(
                year: 2026,
                month: 6,
                day: day,
                hour: hour
            )
        )!
    }
}

@MainActor
private final class ReplenisherAlarmClientSpy: AlarmClient {
    var scheduledOccurrenceBatches: [[AlarmOccurrence]] = []
    var removedIdentifierBatches: [[String]] = []

    func requestAuthorization() async throws -> Bool {
        true
    }

    func schedule(
        reminderID: UUID,
        proposal: ReminderProposal,
        occurrences: [AlarmOccurrence]
    ) async throws {
        scheduledOccurrenceBatches.append(occurrences)
    }

    func remove(ids: [String]) throws {
        removedIdentifierBatches.append(ids)
    }
}
