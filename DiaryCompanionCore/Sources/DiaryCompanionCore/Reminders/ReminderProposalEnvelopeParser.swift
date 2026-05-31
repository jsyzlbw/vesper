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
    public static let startMarker = "[[DIARY_REMINDER_PROPOSAL]]"
    public static let endMarker = "[[/DIARY_REMINDER_PROPOSAL]]"

    public init() {}

    public func parse(_ text: String) throws -> ReminderProposalParseResult {
        let startParts = text.components(separatedBy: Self.startMarker)
        let endParts = text.components(separatedBy: Self.endMarker)

        if startParts.count == 1, endParts.count == 1 {
            return ReminderProposalParseResult(
                visibleText: text.trimmingCharacters(in: .whitespacesAndNewlines),
                proposal: nil
            )
        }

        guard startParts.count == 2, endParts.count == 2,
              let startRange = text.range(of: Self.startMarker),
              let endRange = text.range(of: Self.endMarker),
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
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let text = try container.decode(String.self)
            let formats: [ISO8601DateFormatter.Options] = [
                [.withInternetDateTime, .withFractionalSeconds],
                [.withInternetDateTime],
            ]
            for formatOptions in formats {
                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = formatOptions
                if let date = formatter.date(from: text) {
                    return date
                }
            }
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Expected ISO8601 date string."
            )
        }
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

public enum ReminderProposalEnvelopeParserError: Error, Equatable, Sendable {
    case invalidEnvelope
    case emptyJSON
    case invalidSchedulingMode(String)
    case invalidRecurrenceKind(String)
    case missingField(String)
    case unexpectedField(String)
    case invalidWeekday(Int)
    case invalidRecurrenceEndKind(String)
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
            throw ReminderProposalEnvelopeParserError.invalidSchedulingMode(schedulingMode)
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
    private enum CodingKeys: String, CodingKey, CaseIterable {
        case kind
        case interval
        case weekdays
        case day
        case month
        case end
    }

    var kind: String
    var interval: Int?
    var weekdays: [Int]?
    var day: Int?
    var month: Int?
    var end: ReminderRecurrenceEndDTO?
    var presentFields: Set<String>

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        kind = try container.decode(String.self, forKey: .kind)
        interval = try container.decodeIfPresent(Int.self, forKey: .interval)
        weekdays = try container.decodeIfPresent([Int].self, forKey: .weekdays)
        day = try container.decodeIfPresent(Int.self, forKey: .day)
        month = try container.decodeIfPresent(Int.self, forKey: .month)
        end = try container.decodeIfPresent(ReminderRecurrenceEndDTO.self, forKey: .end)
        presentFields = Set(CodingKeys.allCases.compactMap { key in
            container.contains(key) ? key.rawValue : nil
        })
    }

    func makeRecurrenceRule() throws -> ReminderRecurrenceRule {
        switch kind {
        case "once":
            try rejectUnexpectedFields(allowed: ["kind"])
            return .once
        case "daily":
            try rejectUnexpectedFields(allowed: ["kind", "interval", "end"])
            return .daily(
                interval: try required(interval, path: "recurrence.interval"),
                end: try end?.makeEnd()
            )
        case "weekly":
            try rejectUnexpectedFields(allowed: ["kind", "interval", "weekdays", "end"])
            let weekdays = try required(weekdays, path: "recurrence.weekdays").map { rawValue in
                guard let weekday = ReminderWeekday(rawValue: rawValue) else {
                    throw ReminderProposalEnvelopeParserError.invalidWeekday(rawValue)
                }
                return weekday
            }
            return .weekly(
                interval: try required(interval, path: "recurrence.interval"),
                weekdays: weekdays,
                end: try end?.makeEnd()
            )
        case "monthly":
            try rejectUnexpectedFields(allowed: ["kind", "interval", "day", "end"])
            return .monthly(
                interval: try required(interval, path: "recurrence.interval"),
                day: try required(day, path: "recurrence.day"),
                end: try end?.makeEnd()
            )
        case "monthlyLastDay":
            try rejectUnexpectedFields(allowed: ["kind", "interval", "end"])
            return .monthlyLastDay(
                interval: try required(interval, path: "recurrence.interval"),
                end: try end?.makeEnd()
            )
        case "yearly":
            try rejectUnexpectedFields(allowed: ["kind", "interval", "month", "day", "end"])
            return .yearly(
                interval: try required(interval, path: "recurrence.interval"),
                month: try required(month, path: "recurrence.month"),
                day: try required(day, path: "recurrence.day"),
                end: try end?.makeEnd()
            )
        default:
            throw ReminderProposalEnvelopeParserError.invalidRecurrenceKind(kind)
        }
    }

    private func rejectUnexpectedFields(allowed: Set<String>) throws {
        for key in CodingKeys.allCases where !allowed.contains(key.rawValue) {
            if presentFields.contains(key.rawValue) {
                throw ReminderProposalEnvelopeParserError.unexpectedField(
                    "recurrence.\(key.rawValue)"
                )
            }
        }
    }
}

private struct ReminderRecurrenceEndDTO: Decodable {
    private enum CodingKeys: String, CodingKey, CaseIterable {
        case kind
        case date
        case occurrenceCount
    }

    var kind: String
    var date: Date?
    var occurrenceCount: Int?
    var presentFields: Set<String>

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        kind = try container.decode(String.self, forKey: .kind)
        date = try container.decodeIfPresent(Date.self, forKey: .date)
        occurrenceCount = try container.decodeIfPresent(Int.self, forKey: .occurrenceCount)
        presentFields = Set(CodingKeys.allCases.compactMap { key in
            container.contains(key) ? key.rawValue : nil
        })
    }

    func makeEnd() throws -> ReminderRecurrenceEnd {
        switch kind {
        case "date":
            try rejectUnexpectedFields(allowed: ["kind", "date"])
            return .date(try required(date, path: "recurrence.end.date"))
        case "occurrenceCount":
            try rejectUnexpectedFields(allowed: ["kind", "occurrenceCount"])
            return .occurrenceCount(try required(
                occurrenceCount,
                path: "recurrence.end.occurrenceCount"
            ))
        default:
            throw ReminderProposalEnvelopeParserError.invalidRecurrenceEndKind(kind)
        }
    }

    private func rejectUnexpectedFields(allowed: Set<String>) throws {
        for key in CodingKeys.allCases where !allowed.contains(key.rawValue) {
            if presentFields.contains(key.rawValue) {
                throw ReminderProposalEnvelopeParserError.unexpectedField(
                    "recurrence.end.\(key.rawValue)"
                )
            }
        }
    }
}

private func required<Value>(_ value: Value?, path: String) throws -> Value {
    guard let value else {
        throw ReminderProposalEnvelopeParserError.missingField(path)
    }
    return value
}
