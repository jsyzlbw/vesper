import Foundation
import Testing
import UserNotifications
@testable import DiaryCompanionCore

private let reminderID = UUID(uuidString: "4BE4CF6D-B6D8-4BF0-A06F-89E9767A55CC")!

@Test func preservesLegacySingleNotificationRequestAPI() throws {
    let request = ReminderRequestFactory(calendar: utcCalendar).makeRequest(
        id: "medication-1",
        title: "Take medication",
        body: "After dinner",
        fireDate: date(2026, 6, 1, 20)
    )

    #expect(request.identifier == "medication-1")
    #expect(request.content.title == "Take medication")
    #expect(request.content.body == "After dinner")
    #expect(request.content.sound == UNNotificationSound.default)
    #expect(try trigger(request).repeats == false)
    #expect(try trigger(request).dateComponents.hour == 20)
}

@Test func buildsConcreteOnceRequestWithDefaultSound() throws {
    let requests = try makeRequests(
        start: date(2026, 6, 1, 20),
        recurrence: .once,
        windowStart: date(2026, 6, 1)
    )

    let request = try #require(requests.first)
    #expect(requests.count == 1)
    #expect(request.content.title == "Review plan")
    #expect(request.content.body == "Prepare notes")
    #expect(request.content.sound == UNNotificationSound.default)
    #expect(try fireDate(request) == date(2026, 6, 1, 20))
}

@Test func usesRepeatingTriggerForSafeDailyRule() throws {
    let requests = try makeRequests(
        start: date(2026, 6, 1, 9, 30),
        recurrence: .daily(interval: 1, end: nil),
        windowStart: date(2026, 6, 1, 9)
    )

    let request = try #require(requests.first)
    #expect(requests.count == 1)
    #expect(request.identifier == "\(identifierPrefix).daily")
    #expect(try trigger(request).repeats)
    #expect(try trigger(request).dateComponents.hour == 9)
    #expect(try trigger(request).dateComponents.minute == 30)
}

@Test func usesOneRepeatingTriggerPerWeekdayForSafeWeeklyRule() throws {
    let requests = try makeRequests(
        start: date(2026, 6, 1, 9),
        recurrence: .weekly(
            interval: 1,
            weekdays: [.monday, .wednesday],
            end: nil
        ),
        windowStart: date(2026, 6, 1, 8)
    )

    #expect(requests.map(\.identifier) == [
        "\(identifierPrefix).weekly.2",
        "\(identifierPrefix).weekly.4",
    ])
    #expect(try requests.map { try trigger($0).dateComponents.weekday } == [2, 4])
    #expect(try requests.allSatisfy { try trigger($0).repeats })
}

@Test func usesRepeatingTriggersForSafeMonthlyAndYearlyRules() throws {
    let monthly = try makeRequests(
        start: date(2026, 6, 15, 9),
        recurrence: .monthly(interval: 1, day: 15, end: nil),
        windowStart: date(2026, 6, 15, 8)
    )
    let yearly = try makeRequests(
        start: date(2026, 6, 15, 9),
        recurrence: .yearly(interval: 1, month: 6, day: 15, end: nil),
        windowStart: date(2026, 6, 15, 8)
    )

    #expect(monthly.map(\.identifier) == ["\(identifierPrefix).monthly.15"])
    #expect(try trigger(monthly[0]).repeats)
    #expect(try trigger(monthly[0]).dateComponents.day == 15)
    #expect(yearly.map(\.identifier) == ["\(identifierPrefix).yearly.6.15"])
    #expect(try trigger(yearly[0]).repeats)
    #expect(try trigger(yearly[0]).dateComponents.month == 6)
    #expect(try trigger(yearly[0]).dateComponents.day == 15)
}

@Test func expandsBiweeklyRuleWithoutResettingAnchorPhase() throws {
    let requests = try makeRequests(
        start: date(2026, 1, 5, 9),
        recurrence: .weekly(interval: 2, weekdays: [.monday], end: nil),
        windowStart: date(2026, 1, 12),
        windowDays: 23
    )

    #expect(try requests.map(fireDate) == [
        date(2026, 1, 19, 9),
        date(2026, 2, 2, 9),
    ])
}

@Test func ordersWeeklyConcreteOccurrencesByDateForMondayFirstCalendar() throws {
    var calendar = utcCalendar
    calendar.firstWeekday = 2
    let requests = try ReminderRequestFactory(calendar: calendar).makeRequests(
        reminderID: reminderID,
        proposal: makeProposal(
            start: date(2026, 1, 5, 9),
            recurrence: .weekly(
                interval: 1,
                weekdays: [.sunday, .monday],
                end: .occurrenceCount(3)
            )
        ),
        windowStart: date(2026, 1, 1),
        windowDays: 20
    )

    #expect(try requests.map(fireDate) == [
        date(2026, 1, 5, 9),
        date(2026, 1, 11, 9),
        date(2026, 1, 12, 9),
    ])
}

@Test func expandsMonthlyLastDayAcrossFebruaryLengths() throws {
    let leapYear = try makeRequests(
        start: date(2024, 1, 31, 9),
        recurrence: .monthlyLastDay(interval: 1, end: nil),
        windowStart: date(2024, 1, 1),
        windowDays: 61
    )
    let commonYear = try makeRequests(
        start: date(2025, 1, 31, 9),
        recurrence: .monthlyLastDay(interval: 1, end: nil),
        windowStart: date(2025, 1, 1),
        windowDays: 60
    )

    #expect(try leapYear.map(fireDate) == [
        date(2024, 1, 31, 9),
        date(2024, 2, 29, 9),
    ])
    #expect(try commonYear.map(fireDate) == [
        date(2025, 1, 31, 9),
        date(2025, 2, 28, 9),
    ])
}

@Test func skipsMonthsWithoutConfiguredDay() throws {
    let requests = try makeRequests(
        start: date(2026, 1, 31, 9),
        recurrence: .monthly(
            interval: 1,
            day: 31,
            end: .date(date(2026, 3, 31, 9))
        ),
        windowStart: date(2026, 1, 1),
        windowDays: 91
    )

    #expect(try requests.map(fireDate) == [
        date(2026, 1, 31, 9),
        date(2026, 3, 31, 9),
    ])
}

@Test func skipsNonLeapYearsForYearlyLeapDay() throws {
    let requests = try makeRequests(
        start: date(2024, 2, 29, 9),
        recurrence: .yearly(
            interval: 1,
            month: 2,
            day: 29,
            end: .date(date(2028, 2, 29, 9))
        ),
        windowStart: date(2024, 1, 1),
        windowDays: 1_900
    )

    #expect(try requests.map(fireDate) == [
        date(2024, 2, 29, 9),
        date(2028, 2, 29, 9),
    ])
}

@Test func appliesOccurrenceCountGloballyAcrossRollingWindows() throws {
    let requests = try makeRequests(
        start: date(2026, 1, 1, 9),
        recurrence: .daily(interval: 1, end: .occurrenceCount(3)),
        windowStart: date(2026, 1, 3),
        windowDays: 3
    )

    #expect(try requests.map(fireDate) == [date(2026, 1, 3, 9)])
}

@Test func includesOccurrenceOnRecurrenceEndDate() throws {
    let requests = try makeRequests(
        start: date(2026, 1, 1, 9),
        recurrence: .daily(interval: 1, end: .date(date(2026, 1, 4, 9))),
        windowStart: date(2026, 1, 1),
        windowDays: 5
    )

    #expect(try requests.map(fireDate) == [
        date(2026, 1, 1, 9),
        date(2026, 1, 2, 9),
        date(2026, 1, 3, 9),
        date(2026, 1, 4, 9),
    ])
}

@Test func expandsFutureDailyRuleThatCouldRepeatBeforeFirstOccurrence() throws {
    let requests = try makeRequests(
        start: date(2026, 1, 10, 9),
        recurrence: .daily(interval: 1, end: nil),
        windowStart: date(2026, 1, 1),
        windowDays: 12
    )

    #expect(try requests.map(fireDate) == [
        date(2026, 1, 10, 9),
        date(2026, 1, 11, 9),
        date(2026, 1, 12, 9),
    ])
    #expect(try requests.allSatisfy { try trigger($0).repeats == false })
}

@Test func usesStableConcreteIdentifier() throws {
    let requests = try makeRequests(
        start: Date(timeIntervalSince1970: 1_800_000_000),
        recurrence: .once,
        windowStart: Date(timeIntervalSince1970: 1_799_999_000)
    )

    #expect(requests.map(\.identifier) == ["\(identifierPrefix).at.1800000000"])
}

@Test func rejectsProposalWithoutChosenStartAndNonPositiveWindow() throws {
    let proposal = makeProposal(
        start: nil,
        recurrence: .once,
        schedulingMode: .findFreeTime,
        searchWindow: ReminderSearchWindow(
            start: date(2026, 1, 1),
            end: date(2026, 1, 2)
        )
    )
    let factory = ReminderRequestFactory(calendar: utcCalendar)

    #expect(throws: ReminderRequestFactoryError.missingStart) {
        try factory.makeRequests(
            reminderID: reminderID,
            proposal: proposal,
            windowStart: date(2026, 1, 1)
        )
    }
    #expect(throws: ReminderRequestFactoryError.invalidWindowDays) {
        try factory.makeRequests(
            reminderID: reminderID,
            proposal: makeProposal(),
            windowStart: date(2026, 1, 1),
            windowDays: 0
        )
    }
}

private var utcCalendar: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    return calendar
}

private var identifierPrefix: String {
    "diary.reminder.v1.\(reminderID.uuidString)"
}

private func makeRequests(
    start: Date?,
    recurrence: ReminderRecurrenceRule,
    windowStart: Date,
    windowDays: Int = 90
) throws -> [UNNotificationRequest] {
    try ReminderRequestFactory(calendar: utcCalendar).makeRequests(
        reminderID: reminderID,
        proposal: makeProposal(start: start, recurrence: recurrence),
        windowStart: windowStart,
        windowDays: windowDays
    )
}

private func makeProposal(
    start: Date? = date(2026, 1, 1, 9),
    recurrence: ReminderRecurrenceRule = .once,
    schedulingMode: ReminderSchedulingMode = .fixed,
    searchWindow: ReminderSearchWindow? = nil
) -> ReminderProposal {
    ReminderProposal(
        title: "Review plan",
        notes: "Prepare notes",
        start: start,
        durationMinutes: 30,
        recurrence: recurrence,
        schedulingMode: schedulingMode,
        searchWindow: searchWindow,
        notificationEnabled: true,
        calendarEnabled: false
    )
}

private func trigger(
    _ request: UNNotificationRequest
) throws -> UNCalendarNotificationTrigger {
    try #require(request.trigger as? UNCalendarNotificationTrigger)
}

private func fireDate(_ request: UNNotificationRequest) throws -> Date {
    try #require(utcCalendar.date(from: trigger(request).dateComponents))
}

private func date(
    _ year: Int,
    _ month: Int,
    _ day: Int,
    _ hour: Int = 0,
    _ minute: Int = 0
) -> Date {
    utcCalendar.date(
        from: DateComponents(
            year: year,
            month: month,
            day: day,
            hour: hour,
            minute: minute
        )
    )!
}
