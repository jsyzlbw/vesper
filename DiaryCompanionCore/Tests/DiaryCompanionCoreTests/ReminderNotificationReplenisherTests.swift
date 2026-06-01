import Foundation
import SwiftData
import Testing
import UserNotifications
@testable import DiaryCompanionCore

@MainActor
@Test func replenisherBudgetsEarliestRequestsGloballyAndIsIdempotent() async throws {
    let fixture = try ReplenisherFixture()
    let first = try fixture.makeScheduledReminder(start: fixture.date(day: 1, hour: 9))
    let second = try fixture.makeScheduledReminder(start: fixture.date(day: 1, hour: 9, minute: 30))

    try await fixture.replenisher.replenish(windowStart: fixture.date(day: 1))

    #expect(fixture.notifications.addedIdentifierBatches.count == 1)
    #expect(fixture.notifications.addedIdentifierBatches[0].count == 60)
    #expect(first.notificationIdentifiers.count + second.notificationIdentifiers.count == 60)

    try await fixture.replenisher.replenish(windowStart: fixture.date(day: 1))

    #expect(fixture.notifications.addedIdentifierBatches == [
        fixture.notifications.addedIdentifierBatches[0],
        [],
    ])
    #expect(fixture.notifications.removedIdentifierBatches.isEmpty)
}

@MainActor
@Test func replenisherReplacesExpiredRequestsWhenWindowAdvances() async throws {
    let fixture = try ReplenisherFixture()
    let record = try fixture.makeScheduledReminder(start: fixture.date(day: 1, hour: 9))
    try await fixture.replenisher.replenish(windowStart: fixture.date(day: 1))
    let originalIdentifiers = Set(record.notificationIdentifiers)

    try await fixture.replenisher.replenish(windowStart: fixture.date(day: 20))

    #expect(fixture.notifications.addedIdentifierBatches.count == 2)
    #expect(!fixture.notifications.addedIdentifierBatches[1].isEmpty)
    #expect(fixture.notifications.removedIdentifierBatches == [
        originalIdentifiers.subtracting(record.notificationIdentifiers).sorted()
    ])
    #expect(record.notificationIdentifiers.count == 60)
}

@MainActor
private final class ReplenisherFixture {
    let repository: DiaryRepository
    let notifications = ReplenisherNotificationClientSpy()
    let replenisher: ReminderNotificationReplenisher
    private let calendar: Calendar
    private let container: ModelContainer

    init() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        self.calendar = calendar
        container = try DiaryModelContainerFactory.make(inMemory: true)
        repository = DiaryRepository(context: container.mainContext)
        replenisher = ReminderNotificationReplenisher(
            repository: repository,
            notificationClient: notifications,
            requestFactory: ReminderRequestFactory(calendar: calendar),
            calendar: calendar
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
                calendarEnabled: false
            ),
            sourceMessageID: nil
        )
        try repository.updateReminderExecution(
            id: record.id,
            status: .scheduled,
            notificationResult: .scheduled,
            calendarResult: .notRequested,
            notificationIdentifiers: [],
            calendarEventIdentifier: nil,
            calendarExternalIdentifier: nil
        )
        return record
    }

    func date(day: Int, hour: Int = 0, minute: Int = 0) -> Date {
        calendar.date(
            from: DateComponents(
                year: 2026,
                month: 6,
                day: day,
                hour: hour,
                minute: minute
            )
        )!
    }
}

@MainActor
private final class ReplenisherNotificationClientSpy: ReminderNotificationClient {
    var addedIdentifierBatches: [[String]] = []
    var removedIdentifierBatches: [[String]] = []

    func requestAuthorization() async throws -> Bool {
        true
    }

    func add(_ requests: [UNNotificationRequest]) async throws {
        addedIdentifierBatches.append(requests.map(\.identifier))
    }

    func removePendingRequests(withIdentifiers identifiers: [String]) {
        removedIdentifierBatches.append(identifiers)
    }
}
