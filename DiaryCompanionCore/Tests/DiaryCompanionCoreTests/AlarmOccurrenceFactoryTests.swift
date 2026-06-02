import Foundation
import Testing
@testable import DiaryCompanionCore

@Test func expandsBiweeklySundayAlarmThirtyMinutesBeforeEvent() throws {
    let dates = try AlarmOccurrenceFactory(calendar: utcCalendar).dates(
        proposal: makeProposal(
            start: date(2026, 6, 7, 15),
            recurrence: .weekly(interval: 2, weekdays: [.sunday], end: nil),
            alarmEnabled: true,
            alarmLeadMinutes: 30
        ),
        windowStart: date(2026, 6, 1),
        windowDays: 30
    )

    #expect(dates == [
        date(2026, 6, 7, 14, 30),
        date(2026, 6, 21, 14, 30),
    ])
}

@Test func disabledAlarmHasNoOccurrences() throws {
    let dates = try AlarmOccurrenceFactory(calendar: utcCalendar).dates(
        proposal: makeProposal(
            start: date(2026, 6, 7, 15),
            recurrence: .daily(interval: 1, end: nil),
            alarmEnabled: false,
            alarmLeadMinutes: 30
        ),
        windowStart: date(2026, 6, 1),
        windowDays: 30
    )

    #expect(dates == [])
}

@Test func disabledAlarmDoesNotRequireOccurrenceAnchor() throws {
    let dates = try AlarmOccurrenceFactory(calendar: utcCalendar).dates(
        proposal: makeProposal(
            start: nil,
            alarmEnabled: false
        ),
        windowStart: date(2026, 6, 1)
    )

    #expect(dates == [])
}

@Test func skipsResolvedAlarmDatesBeforeWindowStart() throws {
    let dates = try AlarmOccurrenceFactory(calendar: utcCalendar).dates(
        proposal: makeProposal(
            start: date(2026, 6, 7, 15),
            recurrence: .daily(interval: 1, end: nil),
            alarmEnabled: true,
            alarmLeadMinutes: 30
        ),
        windowStart: date(2026, 6, 9, 15),
        windowDays: 2
    )

    #expect(dates == [
        date(2026, 6, 10, 14, 30),
        date(2026, 6, 11, 14, 30),
    ])
}

@MainActor
@Test func unavailableAlarmClientRejectsScheduling() async throws {
    let client: any AlarmClient = UnavailableAlarmClient()

    await #expect(throws: AlarmClientError.alarmRequiresIOS26) {
        try await client.requestAuthorization()
    }
    await #expect(throws: AlarmClientError.alarmRequiresIOS26) {
        try await client.schedule(
            reminderID: UUID(),
            proposal: makeProposal(alarmEnabled: true),
            windowStart: date(2026, 6, 1)
        )
    }
    try client.remove(ids: ["alarm-id"])
}

@MainActor
@Test func unavailableAlarmClientIgnoresDisabledAlarm() async throws {
    let client = UnavailableAlarmClient()

    let ids = try await client.schedule(
        reminderID: UUID(),
        proposal: makeProposal(alarmEnabled: false),
        windowStart: date(2026, 6, 1)
    )

    #expect(ids == [])
}

private var utcCalendar: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    return calendar
}

private func makeProposal(
    start: Date? = date(2026, 1, 1, 9),
    recurrence: ReminderRecurrenceRule = .once,
    alarmEnabled: Bool,
    alarmLeadMinutes: Int = 0
) -> ReminderProposal {
    ReminderProposal(
        title: "Review plan",
        notes: "Prepare notes",
        start: start,
        durationMinutes: 30,
        recurrence: recurrence,
        schedulingMode: .fixed,
        searchWindow: nil,
        notificationEnabled: true,
        alarmEnabled: alarmEnabled,
        alarmLeadMinutes: alarmLeadMinutes,
        calendarEnabled: false
    )
}

private func date(
    _ year: Int,
    _ month: Int,
    _ day: Int,
    _ hour: Int = 0,
    _ minute: Int = 0,
    calendar: Calendar = utcCalendar
) -> Date {
    calendar.date(
        from: DateComponents(
            year: year,
            month: month,
            day: day,
            hour: hour,
            minute: minute
        )
    )!
}
