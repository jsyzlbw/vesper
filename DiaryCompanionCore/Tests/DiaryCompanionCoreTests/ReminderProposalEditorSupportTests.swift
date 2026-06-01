import Foundation
import Testing
@testable import DiaryCompanionCore

@Test func editorPreservesAISearchWindow() {
    let searchWindow = ReminderSearchWindow(
        start: date(2026, 6, 1, 13),
        end: date(2026, 6, 1, 18)
    )
    let proposal = makeProposal(
        schedulingMode: .findFreeTime,
        searchWindow: searchWindow
    )

    let prepared = ReminderProposalEditorSupport.preparedForEditing(
        proposal,
        now: date(2026, 6, 1, 10, 7),
        calendar: utcCalendar
    )

    #expect(prepared.searchWindow == searchWindow)
}

@Test func editorDefaultsAutomaticSearchWindowToRemainingDay() {
    let proposal = makeProposal(
        schedulingMode: .findFreeTime,
        searchWindow: nil
    )

    let prepared = ReminderProposalEditorSupport.preparedForEditing(
        proposal,
        now: date(2026, 6, 1, 10, 7),
        calendar: utcCalendar
    )

    #expect(prepared.searchWindow == ReminderSearchWindow(
        start: date(2026, 6, 1, 10, 7),
        end: date(2026, 6, 2)
    ))
}

@Test func editorRoundsMissingFixedStartToNextQuarterHour() {
    let proposal = makeProposal(schedulingMode: .fixed)

    let prepared = ReminderProposalEditorSupport.preparedForEditing(
        proposal,
        now: date(2026, 6, 1, 10, 7),
        calendar: utcCalendar
    )

    #expect(prepared.start == date(2026, 6, 1, 10, 15))
}

@Test func editorLeavesAlignedQuarterHourUnchanged() {
    let proposal = makeProposal(schedulingMode: .fixed)

    let prepared = ReminderProposalEditorSupport.preparedForEditing(
        proposal,
        now: date(2026, 6, 1, 10, 15),
        calendar: utcCalendar
    )

    #expect(prepared.start == date(2026, 6, 1, 10, 15))
}

@Test func recurrenceSummaryIncludesRuleAndEnd() {
    #expect(
        ReminderProposalEditorSupport.recurrenceSummary(
            .daily(interval: 1, end: .occurrenceCount(7))
        ) == "每天，持续 7 次"
    )
    #expect(
        ReminderProposalEditorSupport.recurrenceSummary(
            .weekly(interval: 2, weekdays: [.monday, .wednesday], end: nil)
        ) == "每 2 周，周一、周三"
    )
    #expect(
        ReminderProposalEditorSupport.recurrenceSummary(.once) == "仅一次"
    )
}

private func makeProposal(
    schedulingMode: ReminderSchedulingMode,
    searchWindow: ReminderSearchWindow? = nil
) -> ReminderProposal {
    ReminderProposal(
        title: "喝水",
        notes: "",
        start: nil,
        durationMinutes: 10,
        recurrence: .once,
        schedulingMode: schedulingMode,
        searchWindow: searchWindow,
        notificationEnabled: true,
        calendarEnabled: true
    )
}

private var utcCalendar: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    return calendar
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
