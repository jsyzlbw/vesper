import Foundation
import Testing
@testable import DiaryCompanionCore

@Test func validatesOnceReminderProposal() throws {
    try makeProposal(recurrence: .once).validate()
}

@Test func validatesDailyReminderProposal() throws {
    try makeProposal(recurrence: .daily(interval: 1, end: nil)).validate()
}

@Test func validatesBiweeklyMondayReminderProposal() throws {
    try makeProposal(
        recurrence: .weekly(interval: 2, weekdays: [.monday], end: nil)
    ).validate()
}

@Test func validatesMonthlyReminderProposal() throws {
    try makeProposal(
        recurrence: .monthly(interval: 1, day: 15, end: nil)
    ).validate()
}

@Test func validatesMonthlyLastDayReminderProposal() throws {
    try makeProposal(
        recurrence: .monthlyLastDay(interval: 1, end: nil)
    ).validate()
}

@Test func validatesYearlyReminderProposal() throws {
    try makeProposal(
        recurrence: .yearly(interval: 1, month: 6, day: 1, end: nil)
    ).validate()
}

@Test func validatesYearlyLeapDayReminderProposal() throws {
    try makeProposal(
        recurrence: .yearly(interval: 1, month: 2, day: 29, end: nil)
    ).validate()
}

@Test func validatesFindFreeTimeReminderProposal() throws {
    let window = ReminderSearchWindow(
        start: Date(timeIntervalSince1970: 1_000),
        end: Date(timeIntervalSince1970: 2_800)
    )

    try makeProposal(
        start: nil,
        schedulingMode: .findFreeTime,
        searchWindow: window
    ).validate()
}

@Test(arguments: [
    ReminderRecurrenceRule.once,
    .daily(interval: 1, end: .date(Date(timeIntervalSince1970: 2_000))),
    .weekly(interval: 2, weekdays: [.monday, .wednesday], end: .occurrenceCount(4)),
    .monthly(interval: 1, day: 15, end: nil),
    .monthlyLastDay(interval: 1, end: nil),
    .yearly(interval: 1, month: 6, day: 1, end: nil),
])
func reminderProposalSupportsCodableRoundTrip(recurrence: ReminderRecurrenceRule) throws {
    let proposal = makeProposal(recurrence: recurrence)

    let encoded = try JSONEncoder().encode(proposal)
    let decoded = try JSONDecoder().decode(ReminderProposal.self, from: encoded)

    #expect(decoded == proposal)
}

@Test func rejectsEmptyTitle() {
    #expect(throws: ReminderProposalValidationError.emptyTitle) {
        try makeProposal(title: " \n\t").validate()
    }
}

@Test(arguments: [0, 1_441])
func rejectsDurationOutsideAllowedRange(durationMinutes: Int) {
    #expect(throws: ReminderProposalValidationError.invalidDurationMinutes) {
        try makeProposal(durationMinutes: durationMinutes).validate()
    }
}

@Test func rejectsFixedReminderWithoutStart() {
    #expect(throws: ReminderProposalValidationError.missingStart) {
        try makeProposal(start: nil).validate()
    }
}

@Test func rejectsFindFreeTimeReminderWithoutSearchWindow() {
    #expect(throws: ReminderProposalValidationError.missingSearchWindow) {
        try makeProposal(
            start: nil,
            schedulingMode: .findFreeTime,
            searchWindow: nil
        ).validate()
    }
}

@Test func rejectsSearchWindowWithoutPositiveDuration() {
    let date = Date(timeIntervalSince1970: 1_000)
    let window = ReminderSearchWindow(start: date, end: date)

    #expect(throws: ReminderProposalValidationError.invalidSearchWindow) {
        try makeProposal(
            start: nil,
            schedulingMode: .findFreeTime,
            searchWindow: window
        ).validate()
    }
}

@Test func rejectsSearchWindowShorterThanDuration() {
    let window = ReminderSearchWindow(
        start: Date(timeIntervalSince1970: 1_000),
        end: Date(timeIntervalSince1970: 2_800)
    )

    #expect(throws: ReminderProposalValidationError.searchWindowTooShort) {
        try makeProposal(
            start: nil,
            durationMinutes: 60,
            schedulingMode: .findFreeTime,
            searchWindow: window
        ).validate()
    }
}

@Test(arguments: [
    ReminderRecurrenceRule.daily(interval: 0, end: nil),
    .weekly(interval: 0, weekdays: [.monday], end: nil),
    .monthly(interval: 0, day: 1, end: nil),
    .monthlyLastDay(interval: 0, end: nil),
    .yearly(interval: 0, month: 1, day: 1, end: nil),
])
func rejectsNonPositiveRecurrenceInterval(recurrence: ReminderRecurrenceRule) {
    #expect(throws: ReminderProposalValidationError.invalidRecurrenceInterval) {
        try makeProposal(recurrence: recurrence).validate()
    }
}

@Test func rejectsWeeklyReminderWithoutWeekdays() {
    #expect(throws: ReminderProposalValidationError.emptyWeeklyWeekdays) {
        try makeProposal(
            recurrence: .weekly(interval: 1, weekdays: [], end: nil)
        ).validate()
    }
}

@Test func rejectsWeeklyReminderWithDuplicateWeekdays() {
    #expect(throws: ReminderProposalValidationError.duplicateWeeklyWeekdays) {
        try makeProposal(
            recurrence: .weekly(interval: 1, weekdays: [.monday, .monday], end: nil)
        ).validate()
    }
}

@Test(arguments: [0, 32])
func rejectsMonthlyDayOutsideAllowedRange(day: Int) {
    #expect(throws: ReminderProposalValidationError.invalidMonthlyDay) {
        try makeProposal(
            recurrence: .monthly(interval: 1, day: day, end: nil)
        ).validate()
    }
}

@Test(arguments: [0, 13])
func rejectsYearlyMonthOutsideAllowedRange(month: Int) {
    #expect(throws: ReminderProposalValidationError.invalidYearlyMonth) {
        try makeProposal(
            recurrence: .yearly(interval: 1, month: month, day: 1, end: nil)
        ).validate()
    }
}

@Test(arguments: [0, 32])
func rejectsYearlyDayOutsideAllowedRange(day: Int) {
    #expect(throws: ReminderProposalValidationError.invalidYearlyDay) {
        try makeProposal(
            recurrence: .yearly(interval: 1, month: 1, day: day, end: nil)
        ).validate()
    }
}

@Test(arguments: [
    ReminderRecurrenceRule.yearly(interval: 1, month: 2, day: 30, end: nil),
    .yearly(interval: 1, month: 4, day: 31, end: nil),
])
func rejectsImpossibleYearlyDate(recurrence: ReminderRecurrenceRule) {
    #expect(throws: ReminderProposalValidationError.invalidYearlyDate) {
        try makeProposal(recurrence: recurrence).validate()
    }
}

@Test func rejectsNonPositiveOccurrenceCount() {
    #expect(throws: ReminderProposalValidationError.invalidOccurrenceCount) {
        try makeProposal(
            recurrence: .daily(interval: 1, end: .occurrenceCount(0))
        ).validate()
    }
}

@Test func rejectsRecurrenceEndDateBeforeFixedStart() {
    #expect(throws: ReminderProposalValidationError.invalidRecurrenceEndDate) {
        try makeProposal(
            start: Date(timeIntervalSince1970: 1_000),
            recurrence: .daily(
                interval: 1,
                end: .date(Date(timeIntervalSince1970: 999))
            )
        ).validate()
    }
}

@Test func rejectsRecurrenceEndDateBeforeFindFreeTimeWindowStart() {
    let window = ReminderSearchWindow(
        start: Date(timeIntervalSince1970: 1_000),
        end: Date(timeIntervalSince1970: 4_600)
    )

    #expect(throws: ReminderProposalValidationError.invalidRecurrenceEndDate) {
        try makeProposal(
            start: nil,
            recurrence: .daily(
                interval: 1,
                end: .date(Date(timeIntervalSince1970: 999))
            ),
            schedulingMode: .findFreeTime,
            searchWindow: window
        ).validate()
    }
}

private func makeProposal(
    title: String = "Review tomorrow's plan",
    start: Date? = Date(timeIntervalSince1970: 1_000),
    durationMinutes: Int = 30,
    recurrence: ReminderRecurrenceRule = .once,
    schedulingMode: ReminderSchedulingMode = .fixed,
    searchWindow: ReminderSearchWindow? = nil
) -> ReminderProposal {
    ReminderProposal(
        title: title,
        notes: "Prepare the daily summary.",
        start: start,
        durationMinutes: durationMinutes,
        recurrence: recurrence,
        schedulingMode: schedulingMode,
        searchWindow: searchWindow,
        notificationEnabled: true,
        calendarEnabled: true
    )
}
