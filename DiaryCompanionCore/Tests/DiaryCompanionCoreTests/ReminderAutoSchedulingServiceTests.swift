import Foundation
import Testing
@testable import DiaryCompanionCore

@MainActor
@Test func autoSchedulingReturnsFixedProposalWithoutCalendarAccess() async throws {
    let calendarClient = AutoSchedulingCalendarClientSpy()
    let proposal = makeAutoSchedulingProposal(mode: .fixed)

    let resolved = try await ReminderAutoSchedulingService(
        calendarClient: calendarClient
    ).resolve(proposal)

    #expect(resolved == proposal)
    #expect(calendarClient.authorizationRequestCount == 0)
}

@MainActor
@Test func autoSchedulingUsesEarliestFreeSlotAcrossVisibleCalendars() async throws {
    let calendarClient = AutoSchedulingCalendarClientSpy()
    calendarClient.busyIntervals = [
        DateInterval(start: date(9, 0), end: date(10, 30)),
        DateInterval(start: date(11, 0), end: date(12, 0)),
    ]

    let resolved = try await ReminderAutoSchedulingService(
        calendarClient: calendarClient,
        calendar: utcCalendar
    ).resolve(makeAutoSchedulingProposal())

    #expect(resolved.start == date(10, 30))
    #expect(calendarClient.requestedWindows == [
        DateInterval(start: date(9, 0), end: date(18, 0))
    ])
}

@MainActor
@Test func autoSchedulingSkipsWrongWeekdayForWeeklyRule() async throws {
    let calendarClient = AutoSchedulingCalendarClientSpy()
    let proposal = makeAutoSchedulingProposal(
        searchStart: date(9, 0, day: 1),
        searchEnd: date(18, 0, day: 3),
        recurrence: .weekly(interval: 1, weekdays: [.tuesday], end: nil)
    )

    let resolved = try await ReminderAutoSchedulingService(
        calendarClient: calendarClient,
        calendar: utcCalendar
    ).resolve(proposal)

    #expect(resolved.start == date(0, 0, day: 2))
}

@MainActor
@Test func autoSchedulingRejectsDeniedCalendarPermission() async throws {
    let calendarClient = AutoSchedulingCalendarClientSpy()
    calendarClient.authorizationGranted = false

    await #expect(throws: ReminderAutoSchedulingError.calendarPermissionDenied) {
        try await ReminderAutoSchedulingService(
            calendarClient: calendarClient
        ).resolve(makeAutoSchedulingProposal())
    }
}

@MainActor
@Test func autoSchedulingRejectsFullWindow() async throws {
    let calendarClient = AutoSchedulingCalendarClientSpy()
    calendarClient.busyIntervals = [
        DateInterval(start: date(9, 0), end: date(18, 0)),
    ]

    await #expect(throws: ReminderAutoSchedulingError.noAvailableSlot) {
        try await ReminderAutoSchedulingService(
            calendarClient: calendarClient
        ).resolve(makeAutoSchedulingProposal())
    }
}

@MainActor
private final class AutoSchedulingCalendarClientSpy: CalendarClient {
    var authorizationGranted = true
    var authorizationRequestCount = 0
    var busyIntervals: [DateInterval] = []
    var requestedWindows: [DateInterval] = []

    func requestFullAccess() async throws -> Bool {
        authorizationRequestCount += 1
        return authorizationGranted
    }

    func busyIntervals(in searchWindow: DateInterval) async throws -> [DateInterval] {
        requestedWindows.append(searchWindow)
        return busyIntervals
    }

    func createEvent(for proposal: ReminderProposal) async throws -> CalendarEventReference {
        CalendarEventReference(eventIdentifier: "unused", externalIdentifier: nil)
    }

    func removeEvent(reference: CalendarEventReference) throws {}
}

private func makeAutoSchedulingProposal(
    mode: ReminderSchedulingMode = .findFreeTime,
    searchStart: Date = date(9, 0),
    searchEnd: Date = date(18, 0),
    recurrence: ReminderRecurrenceRule = .once
) -> ReminderProposal {
    ReminderProposal(
        title: "Study",
        notes: "",
        start: mode == .fixed ? date(9, 0) : nil,
        durationMinutes: 30,
        recurrence: recurrence,
        schedulingMode: mode,
        searchWindow: mode == .fixed
            ? nil
            : ReminderSearchWindow(start: searchStart, end: searchEnd),
        notificationEnabled: true,
        calendarEnabled: true
    )
}

private var utcCalendar: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    return calendar
}

private func date(_ hour: Int, _ minute: Int, day: Int = 1) -> Date {
    DateComponents(
        calendar: utcCalendar,
        timeZone: TimeZone(secondsFromGMT: 0),
        year: 2026,
        month: 6,
        day: day,
        hour: hour,
        minute: minute
    ).date!
}
