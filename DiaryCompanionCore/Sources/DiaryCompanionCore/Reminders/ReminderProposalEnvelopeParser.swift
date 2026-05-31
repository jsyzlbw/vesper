import Foundation

public struct ReminderProposalParseResult: Equatable, Sendable {
    public var visibleText: String
    public var proposal: ReminderProposal?

    public init(visibleText: String, proposal: ReminderProposal?) {
        self.visibleText = visibleText
        self.proposal = proposal
    }
}

public struct ReminderProposalEnvelopeParser: Sendable {
    private let startMarker = "[[DIARY_REMINDER_PROPOSAL]]"
    private let endMarker = "[[/DIARY_REMINDER_PROPOSAL]]"

    public init() {}

    public func parse(_ text: String) throws -> ReminderProposalParseResult {
        let startParts = text.components(separatedBy: startMarker)
        let endParts = text.components(separatedBy: endMarker)

        if startParts.count == 1, endParts.count == 1 {
            return ReminderProposalParseResult(
                visibleText: text.trimmingCharacters(in: .whitespacesAndNewlines),
                proposal: nil
            )
        }

        guard startParts.count == 2, endParts.count == 2,
              let startRange = text.range(of: startMarker),
              let endRange = text.range(of: endMarker),
              startRange.upperBound <= endRange.lowerBound
        else {
            throw ReminderProposalEnvelopeParserError.invalidEnvelope
        }

        let json = text[startRange.upperBound..<endRange.lowerBound]
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !json.isEmpty else {
            throw ReminderProposalEnvelopeParserError.emptyJSON
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let dto = try decoder.decode(ReminderProposalDTO.self, from: Data(json.utf8))
        let proposal = try dto.makeProposal()
        try proposal.validate()

        let visibleText = String(text[..<startRange.lowerBound])
            + String(text[endRange.upperBound...])
        return ReminderProposalParseResult(
            visibleText: visibleText.trimmingCharacters(in: .whitespacesAndNewlines),
            proposal: proposal
        )
    }
}

private enum ReminderProposalEnvelopeParserError: Error {
    case invalidEnvelope
    case emptyJSON
    case invalidSchedulingMode
    case invalidRecurrenceKind
    case missingRecurrenceField
    case invalidWeekday
    case invalidRecurrenceEndKind
}

private struct ReminderProposalDTO: Decodable {
    var title: String
    var notes: String
    var start: Date?
    var durationMinutes: Int
    var recurrence: ReminderRecurrenceRuleDTO
    var schedulingMode: String
    var searchWindow: ReminderSearchWindowDTO?
    var notificationEnabled: Bool
    var calendarEnabled: Bool

    func makeProposal() throws -> ReminderProposal {
        guard let schedulingMode = ReminderSchedulingMode(rawValue: schedulingMode) else {
            throw ReminderProposalEnvelopeParserError.invalidSchedulingMode
        }

        return ReminderProposal(
            title: title,
            notes: notes,
            start: start,
            durationMinutes: durationMinutes,
            recurrence: try recurrence.makeRecurrenceRule(),
            schedulingMode: schedulingMode,
            searchWindow: searchWindow?.makeSearchWindow(),
            notificationEnabled: notificationEnabled,
            calendarEnabled: calendarEnabled
        )
    }
}

private struct ReminderSearchWindowDTO: Decodable {
    var start: Date
    var end: Date

    func makeSearchWindow() -> ReminderSearchWindow {
        ReminderSearchWindow(start: start, end: end)
    }
}

private struct ReminderRecurrenceRuleDTO: Decodable {
    var kind: String
    var interval: Int?
    var weekdays: [Int]?
    var day: Int?
    var month: Int?
    var end: ReminderRecurrenceEndDTO?

    func makeRecurrenceRule() throws -> ReminderRecurrenceRule {
        switch kind {
        case "once":
            return .once
        case "daily":
            return .daily(interval: try required(interval), end: try end?.makeEnd())
        case "weekly":
            let weekdays = try required(weekdays).map { rawValue in
                guard let weekday = ReminderWeekday(rawValue: rawValue) else {
                    throw ReminderProposalEnvelopeParserError.invalidWeekday
                }
                return weekday
            }
            return .weekly(
                interval: try required(interval),
                weekdays: weekdays,
                end: try end?.makeEnd()
            )
        case "monthly":
            return .monthly(
                interval: try required(interval),
                day: try required(day),
                end: try end?.makeEnd()
            )
        case "monthlyLastDay":
            return .monthlyLastDay(
                interval: try required(interval),
                end: try end?.makeEnd()
            )
        case "yearly":
            return .yearly(
                interval: try required(interval),
                month: try required(month),
                day: try required(day),
                end: try end?.makeEnd()
            )
        default:
            throw ReminderProposalEnvelopeParserError.invalidRecurrenceKind
        }
    }
}

private struct ReminderRecurrenceEndDTO: Decodable {
    var kind: String
    var date: Date?
    var occurrenceCount: Int?

    func makeEnd() throws -> ReminderRecurrenceEnd {
        switch kind {
        case "date":
            return .date(try required(date))
        case "occurrenceCount":
            return .occurrenceCount(try required(occurrenceCount))
        default:
            throw ReminderProposalEnvelopeParserError.invalidRecurrenceEndKind
        }
    }
}

private func required<Value>(_ value: Value?) throws -> Value {
    guard let value else {
        throw ReminderProposalEnvelopeParserError.missingRecurrenceField
    }
    return value
}
