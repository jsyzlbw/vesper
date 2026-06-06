import Foundation
import Testing
@testable import DiaryCompanionCore

@Test func exposesReminderProposalEnvelopeMarkers() {
    #expect(ReminderProposalEnvelopeParser.startMarker == "[[DIARY_REMINDER_PROPOSAL]]")
    #expect(ReminderProposalEnvelopeParser.endMarker == "[[/DIARY_REMINDER_PROPOSAL]]")
}

@Test func parsesProseOnlyReminderProposalResponse() throws {
    let result = try ReminderProposalEnvelopeParser().parse("  先记录下来，稍后再安排。 \n")

    #expect(result == ReminderProposalParseResult(
        visibleText: "先记录下来，稍后再安排。",
        proposal: nil
    ))
    #expect(result.proposals.isEmpty)
}

@Test func parsesWeeklyReminderProposalEnvelopeAndRemovesItFromVisibleText() throws {
    let text = """
      已整理好每周回顾提醒。
    [[DIARY_REMINDER_PROPOSAL]]
    \(proposalJSON(
        recurrence: #"{"kind":"weekly","interval":2,"weekdays":[2,4]}"#
    ))
    [[/DIARY_REMINDER_PROPOSAL]]
    """

    let result = try ReminderProposalEnvelopeParser().parse(text)

    #expect(result.visibleText == "已整理好每周回顾提醒。")
    #expect(result.proposal == ReminderProposal(
        title: "Review plan",
        notes: "Prepare notes.",
        start: iso8601Date("2026-06-01T19:30:00+08:00"),
        durationMinutes: 30,
        recurrence: .weekly(
            interval: 2,
            weekdays: [.monday, .wednesday],
            end: nil
        ),
        schedulingMode: .fixed,
        searchWindow: nil,
        notificationEnabled: true,
        calendarEnabled: false
    ))
    #expect(result.proposals.count == 1)
}

@Test func parsesMultipleReminderProposalEnvelopesAndRemovesThemFromVisibleText() throws {
    let breakfast = proposalJSON(
        title: "Breakfast",
        notes: "Leave space for breakfast.",
        recurrence: #"{"kind":"once"}"#,
        start: #""2026-06-02T08:30:00+08:00""#,
        duration: 30
    )
    let study = proposalJSON(
        title: "Study information theory",
        notes: "Finish half of this week's content.",
        recurrence: #"{"kind":"once"}"#,
        start: #""2026-06-02T09:30:00+08:00""#,
        duration: 120
    )
    let result = try ReminderProposalEnvelopeParser().parse("""
    我把明天拆成两个事项：
    \(reminderProposalEnvelope(study))
    中间可休息。
    \(reminderProposalEnvelope(breakfast))
    请逐项确认。
    """)

    #expect(result.visibleText == "我把明天拆成两个事项：\n中间可休息。\n请逐项确认。")
    #expect(result.proposals.map(\.title) == [
        "Breakfast",
        "Study information theory",
    ])
    #expect(result.proposal?.title == "Breakfast")
}

@Test func parsesFindFreeTimeReminderWithSearchWindow() throws {
    let json = proposalJSON(
        recurrence: #"{"kind":"once"}"#,
        schedulingMode: "findFreeTime",
        start: "null",
        searchWindow: #"{"start":"2026-06-01T19:30:00+08:00","end":"2026-06-01T21:30:00+08:00"}"#
    )

    let proposal = try parseProposal(json)

    #expect(proposal.schedulingMode == .findFreeTime)
    #expect(proposal.start == nil)
    #expect(proposal.searchWindow == ReminderSearchWindow(
        start: iso8601Date("2026-06-01T19:30:00+08:00"),
        end: iso8601Date("2026-06-01T21:30:00+08:00")
    ))
}

@Test func mapsReminderOutputLeadTimesAndAlarmIntent() throws {
    let proposal = try parseProposal(proposalJSON(
        recurrence: #"{"kind":"once"}"#,
        outputConfiguration: """
        "notificationEnabled": true,
        "notificationLeadMinutes": 15,
        "alarmEnabled": true,
        "alarmLeadMinutes": 30,
        "calendarEnabled": false
        """
    ))

    #expect(proposal.notificationLeadMinutes == 15)
    #expect(proposal.alarmEnabled)
    #expect(proposal.alarmLeadMinutes == 30)
}

@Test func defaultsLegacyReminderOutputConfiguration() throws {
    let proposal = try parseProposal(proposalJSON(
        recurrence: #"{"kind":"once"}"#
    ))

    #expect(proposal.notificationLeadMinutes == 0)
    #expect(!proposal.alarmEnabled)
    #expect(proposal.alarmLeadMinutes == 0)
}

@Test func defaultsMissingAlarmOnlyDurationToOneMinute() throws {
    let proposal = try parseProposal(proposalJSON(
        recurrence: #"{"kind":"once"}"#,
        duration: nil,
        outputConfiguration: """
        "notificationEnabled": false,
        "alarmEnabled": true,
        "alarmLeadMinutes": 0,
        "calendarEnabled": false
        """
    ))

    #expect(proposal.durationMinutes == 1)
}

@Test func normalizesZeroAlarmOnlyDurationToOneMinute() throws {
    let proposal = try parseProposal(proposalJSON(
        recurrence: #"{"kind":"once"}"#,
        duration: 0,
        outputConfiguration: """
        "notificationEnabled": false,
        "alarmEnabled": true,
        "alarmLeadMinutes": 0,
        "calendarEnabled": false
        """
    ))

    #expect(proposal.durationMinutes == 1)
}

@Test func mapsAllReminderRecurrenceKinds() throws {
    let cases: [(String, ReminderRecurrenceRule)] = [
        (#"{"kind":"once"}"#, .once),
        (#"{"kind":"daily","interval":1}"#, .daily(interval: 1, end: nil)),
        (
            #"{"kind":"weekly","interval":1,"weekdays":[2]}"#,
            .weekly(interval: 1, weekdays: [.monday], end: nil)
        ),
        (
            #"{"kind":"monthly","interval":1,"day":1}"#,
            .monthly(interval: 1, day: 1, end: nil)
        ),
        (
            #"{"kind":"monthlyLastDay","interval":1}"#,
            .monthlyLastDay(interval: 1, end: nil)
        ),
        (
            #"{"kind":"yearly","interval":1,"month":6,"day":1}"#,
            .yearly(interval: 1, month: 6, day: 1, end: nil)
        ),
    ]

    for (recurrenceJSON, expected) in cases {
        let start = recurrenceJSON.contains("monthlyLastDay")
            ? #""2026-06-30T19:30:00+08:00""#
            : #""2026-06-01T19:30:00+08:00""#

        #expect(try parseProposal(
            proposalJSON(recurrence: recurrenceJSON, start: start)
        ).recurrence == expected)
    }
}

@Test func mapsRecurrenceEndDate() throws {
    let proposal = try parseProposal(proposalJSON(
        recurrence: """
        {"kind":"daily","interval":1,"end":{"kind":"date","date":"2026-06-30T19:30:00+08:00"}}
        """
    ))

    #expect(proposal.recurrence == .daily(
        interval: 1,
        end: .date(iso8601Date("2026-06-30T19:30:00+08:00"))
    ))
}

@Test func mapsRecurrenceEndOccurrenceCount() throws {
    let proposal = try parseProposal(proposalJSON(
        recurrence: #"{"kind":"daily","interval":1,"end":{"kind":"occurrenceCount","occurrenceCount":4}}"#
    ))

    #expect(proposal.recurrence == .daily(interval: 1, end: .occurrenceCount(4)))
}

@Test(arguments: [
    #""2026-06-01T11:30:00Z""#,
    #""2026-06-01T11:30:00.125Z""#,
])
func parsesSupportedISO8601Dates(start: String) throws {
    let proposal = try parseProposal(proposalJSON(
        recurrence: #"{"kind":"once"}"#,
        start: start
    ))

    #expect(proposal.start != nil)
}

@Test func rejectsMalformedReminderProposalJSON() {
    #expect(throws: (any Error).self) {
        try parseProposal("{not-json}")
    }
}

@Test func rejectsEmptyReminderProposalJSON() {
    #expect(throws: ReminderProposalEnvelopeParserError.emptyJSON) {
        try parseProposal(" \n ")
    }
}

@Test func rejectsInvalidSchedulingMode() {
    #expect(throws: ReminderProposalEnvelopeParserError.invalidSchedulingMode("floating")) {
        try parseProposal(proposalJSON(
            recurrence: #"{"kind":"once"}"#,
            schedulingMode: "floating"
        ))
    }
}

@Test func rejectsInvalidMappedDomainProposal() {
    #expect(throws: ReminderProposalValidationError.missingStart) {
        try parseProposal(proposalJSON(
            recurrence: #"{"kind":"once"}"#,
            start: "null"
        ))
    }
}

@Test(arguments: [
    "[[DIARY_REMINDER_PROPOSAL]]\n{}",
    "{}\n[[/DIARY_REMINDER_PROPOSAL]]",
    "[[/DIARY_REMINDER_PROPOSAL]]\n{}\n[[DIARY_REMINDER_PROPOSAL]]",
])
func rejectsUnmatchedReminderProposalMarker(text: String) {
    #expect(throws: ReminderProposalEnvelopeParserError.invalidEnvelope) {
        try ReminderProposalEnvelopeParser().parse(text)
    }
}

@Test func rejectsUnclosedSecondReminderProposalEnvelope() {
    let envelope = reminderProposalEnvelope(proposalJSON(recurrence: #"{"kind":"once"}"#))

    #expect(throws: ReminderProposalEnvelopeParserError.invalidEnvelope) {
        try ReminderProposalEnvelopeParser().parse("\(envelope)\n[[DIARY_REMINDER_PROPOSAL]]")
    }
}

@Test func rejectsInvalidRecurrenceKind() {
    #expect(throws: ReminderProposalEnvelopeParserError.invalidRecurrenceKind("hourly")) {
        try parseProposal(proposalJSON(
            recurrence: #"{"kind":"hourly","interval":1}"#
        ))
    }
}

@Test func rejectsInvalidWeekday() {
    #expect(throws: ReminderProposalEnvelopeParserError.invalidWeekday(0)) {
        try parseProposal(proposalJSON(
            recurrence: #"{"kind":"weekly","interval":1,"weekdays":[0]}"#
        ))
    }
}

@Test func rejectsMissingRequiredRecurrenceField() {
    #expect(throws: ReminderProposalEnvelopeParserError.missingField("recurrence.day")) {
        try parseProposal(proposalJSON(
            recurrence: #"{"kind":"monthly","interval":1}"#
        ))
    }
}

@Test(arguments: [
    (#"{"kind":"once","interval":1}"#, "recurrence.interval"),
    (#"{"kind":"daily","interval":1,"weekdays":[2]}"#, "recurrence.weekdays"),
])
func rejectsUnexpectedRecurrenceField(recurrenceJSON: String, path: String) {
    #expect(throws: ReminderProposalEnvelopeParserError.unexpectedField(path)) {
        try parseProposal(proposalJSON(recurrence: recurrenceJSON))
    }
}

@Test func rejectsUnexpectedRecurrenceEndField() {
    #expect(throws: ReminderProposalEnvelopeParserError.unexpectedField(
        "recurrence.end.occurrenceCount"
    )) {
        try parseProposal(proposalJSON(
            recurrence: """
            {"kind":"daily","interval":1,"end":{"kind":"date","date":"2026-06-30T19:30:00+08:00","occurrenceCount":4}}
            """
        ))
    }
}

private func parseProposal(_ json: String) throws -> ReminderProposal {
    let result = try ReminderProposalEnvelopeParser().parse(
        reminderProposalEnvelope(json)
    )
    return try #require(result.proposal)
}

private func reminderProposalEnvelope(_ json: String) -> String {
    """
    \(ReminderProposalEnvelopeParser.startMarker)
    \(json)
    \(ReminderProposalEnvelopeParser.endMarker)
    """
}

private func proposalJSON(
    title: String = "Review plan",
    notes: String = "Prepare notes.",
    recurrence: String,
    schedulingMode: String = "fixed",
    start: String = #""2026-06-01T19:30:00+08:00""#,
    searchWindow: String = "null",
    duration: Int? = 30,
    outputConfiguration: String = """
    "notificationEnabled": true,
    "calendarEnabled": false
    """
) -> String {
    """
    {
      "title": "\(title)",
      "notes": "\(notes)",
      "start": \(start),
      \(duration.map { #""durationMinutes": \#($0),"# } ?? "")
      "recurrence": \(recurrence),
      "schedulingMode": "\(schedulingMode)",
      "searchWindow": \(searchWindow),
      \(outputConfiguration)
    }
    """
}

private func iso8601Date(_ text: String) -> Date {
    ISO8601DateFormatter().date(from: text)!
}
