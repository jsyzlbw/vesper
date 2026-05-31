import Foundation

public enum ReminderWeekday: Int, Codable, CaseIterable, Equatable, Sendable {
    case sunday = 1
    case monday
    case tuesday
    case wednesday
    case thursday
    case friday
    case saturday
}

public enum ReminderRecurrenceEnd: Codable, Equatable, Sendable {
    case date(Date)
    case occurrenceCount(Int)
}

public enum ReminderRecurrenceRule: Codable, Equatable, Sendable {
    case once
    case daily(interval: Int, end: ReminderRecurrenceEnd?)
    case weekly(
        interval: Int,
        weekdays: [ReminderWeekday],
        end: ReminderRecurrenceEnd?
    )
    case monthly(interval: Int, day: Int, end: ReminderRecurrenceEnd?)
    case monthlyLastDay(interval: Int, end: ReminderRecurrenceEnd?)
    case yearly(
        interval: Int,
        month: Int,
        day: Int,
        end: ReminderRecurrenceEnd?
    )
}

public enum ReminderSchedulingMode: String, Codable, Equatable, Sendable {
    case fixed
    case findFreeTime
}

public struct ReminderSearchWindow: Codable, Equatable, Sendable {
    public var start: Date
    public var end: Date

    public init(start: Date, end: Date) {
        self.start = start
        self.end = end
    }
}

public enum ReminderProposalValidationError: Error, Equatable, Sendable {
    case emptyTitle
    case invalidDurationMinutes
    case missingStart
    case missingSearchWindow
    case invalidSearchWindow
    case invalidRecurrenceInterval
    case emptyWeeklyWeekdays
    case invalidMonthlyDay
    case invalidYearlyMonth
    case invalidYearlyDay
    case invalidOccurrenceCount
}

public struct ReminderProposal: Codable, Equatable, Sendable {
    public var title: String
    public var notes: String
    public var start: Date?
    public var durationMinutes: Int
    public var recurrence: ReminderRecurrenceRule
    public var schedulingMode: ReminderSchedulingMode
    public var searchWindow: ReminderSearchWindow?
    public var notificationEnabled: Bool
    public var calendarEnabled: Bool

    public init(
        title: String,
        notes: String,
        start: Date?,
        durationMinutes: Int,
        recurrence: ReminderRecurrenceRule,
        schedulingMode: ReminderSchedulingMode,
        searchWindow: ReminderSearchWindow?,
        notificationEnabled: Bool,
        calendarEnabled: Bool
    ) {
        self.title = title
        self.notes = notes
        self.start = start
        self.durationMinutes = durationMinutes
        self.recurrence = recurrence
        self.schedulingMode = schedulingMode
        self.searchWindow = searchWindow
        self.notificationEnabled = notificationEnabled
        self.calendarEnabled = calendarEnabled
    }

    public func validate() throws {
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ReminderProposalValidationError.emptyTitle
        }
        guard (1...1_440).contains(durationMinutes) else {
            throw ReminderProposalValidationError.invalidDurationMinutes
        }

        switch schedulingMode {
        case .fixed:
            guard start != nil else {
                throw ReminderProposalValidationError.missingStart
            }
        case .findFreeTime:
            guard searchWindow != nil else {
                throw ReminderProposalValidationError.missingSearchWindow
            }
        }

        if let searchWindow, searchWindow.end <= searchWindow.start {
            throw ReminderProposalValidationError.invalidSearchWindow
        }

        try recurrence.validate()
    }
}

private extension ReminderRecurrenceRule {
    func validate() throws {
        switch self {
        case .once:
            break
        case let .daily(interval, end):
            try validate(interval: interval, end: end)
        case let .weekly(interval, weekdays, end):
            try validate(interval: interval, end: end)
            guard !weekdays.isEmpty else {
                throw ReminderProposalValidationError.emptyWeeklyWeekdays
            }
        case let .monthly(interval, day, end):
            try validate(interval: interval, end: end)
            guard (1...31).contains(day) else {
                throw ReminderProposalValidationError.invalidMonthlyDay
            }
        case let .monthlyLastDay(interval, end):
            try validate(interval: interval, end: end)
        case let .yearly(interval, month, day, end):
            try validate(interval: interval, end: end)
            guard (1...12).contains(month) else {
                throw ReminderProposalValidationError.invalidYearlyMonth
            }
            guard (1...31).contains(day) else {
                throw ReminderProposalValidationError.invalidYearlyDay
            }
        }
    }

    func validate(interval: Int, end: ReminderRecurrenceEnd?) throws {
        guard interval > 0 else {
            throw ReminderProposalValidationError.invalidRecurrenceInterval
        }
        if case let .occurrenceCount(count) = end, count <= 0 {
            throw ReminderProposalValidationError.invalidOccurrenceCount
        }
    }
}
