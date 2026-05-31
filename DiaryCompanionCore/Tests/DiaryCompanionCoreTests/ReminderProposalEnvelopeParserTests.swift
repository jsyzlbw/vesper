import Foundation
import Testing
@testable import DiaryCompanionCore

@Test func parsesProseOnlyReminderProposalResponse() throws {
    let result = try ReminderProposalEnvelopeParser().parse("  先记录下来，稍后再安排。 \n")

    #expect(result == ReminderProposalParseResult(
        visibleText: "先记录下来，稍后再安排。",
        proposal: nil
    ))
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

@Test func rejectsMalformedReminderProposalJSON() {
    #expect(throws: (any Error).self) {
        try parseProposal("{not-json}")
    }
}

@Test func rejectsEmptyReminderProposalJSON() {
    #expect(throws: (any Error).self) {
        try parseProposal(" \n ")
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
])
func rejectsUnmatchedReminderProposalMarker(text: String) {
    #expect(throws: (any Error).self) {
        try ReminderProposalEnvelopeParser().parse(text)
    }
}

@Test func rejectsMultipleReminderProposalEnvelopes() {
    let envelope = reminderProposalEnvelope(proposalJSON(recurrence: #"{"kind":"once"}"#))

    #expect(throws: (any Error).self) {
        try ReminderProposalEnvelopeParser().parse("\(envelope)\n\(envelope)")
    }
}

@Test(arguments: [
    #"{"kind":"hourly","interval":1}"#,
    #"{"kind":"weekly","interval":1,"weekdays":[0]}"#,
    #"{"kind":"monthly","interval":1}"#,
])
func rejectsInvalidRecurrenceDTO(recurrenceJSON: String) {
    #expect(throws: (any Error).self) {
        try parseProposal(proposalJSON(recurrence: recurrenceJSON))
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
    [[DIARY_REMINDER_PROPOSAL]]
    \(json)
    [[/DIARY_REMINDER_PROPOSAL]]
    """
}

private func proposalJSON(
    recurrence: String,
    schedulingMode: String = "fixed",
    start: String = #""2026-06-01T19:30:00+08:00""#,
    searchWindow: String = "null"
) -> String {
    """
    {
      "title": "Review plan",
      "notes": "Prepare notes.",
      "start": \(start),
      "durationMinutes": 30,
      "recurrence": \(recurrence),
      "schedulingMode": "\(schedulingMode)",
      "searchWindow": \(searchWindow),
      "notificationEnabled": true,
      "calendarEnabled": false
    }
    """
}

private func iso8601Date(_ text: String) -> Date {
    ISO8601DateFormatter().date(from: text)!
}
