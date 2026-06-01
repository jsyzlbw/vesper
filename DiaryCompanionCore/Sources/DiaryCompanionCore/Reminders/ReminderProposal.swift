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

public enum ReminderProposalStatus: String, Codable, Equatable, Sendable {
    case pendingConfirmation
    case executing
    case scheduled
    case cancelled
}

public enum ReminderExecutionResult: String, Codable, Equatable, Sendable {
    case notRequested
    case pending
    case scheduled
    case created
    case permissionDenied
    case failed
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
    case searchWindowTooShort
    case invalidRecurrenceInterval
    case emptyWeeklyWeekdays
    case duplicateWeeklyWeekdays
    case invalidMonthlyDay
    case invalidYearlyMonth
    case invalidYearlyDay
    case invalidYearlyDate
    case invalidOccurrenceCount
    case invalidRecurrenceEndDate
    case invalidFirstOccurrence
    case startIsInThePast
    case searchWindowIsInThePast
}

extension ReminderProposalValidationError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .emptyTitle:
            "提醒标题不能为空。"
        case .invalidDurationMinutes:
            "事件持续时间必须在 1 到 1440 分钟之间。"
        case .missingStart:
            "请选择提醒时间。"
        case .missingSearchWindow:
            "请选择自动安排的时间范围。"
        case .invalidSearchWindow:
            "自动安排的结束时间必须晚于开始时间。"
        case .searchWindowTooShort:
            "自动安排的时间范围短于事件持续时间。"
        case .invalidRecurrenceInterval:
            "重复间隔必须大于 0。"
        case .emptyWeeklyWeekdays:
            "每周提醒至少要选择一天。"
        case .duplicateWeeklyWeekdays:
            "每周提醒包含重复的星期。"
        case .invalidMonthlyDay:
            "每月提醒日期必须在 1 到 31 之间。"
        case .invalidYearlyMonth:
            "年度提醒月份必须在 1 到 12 之间。"
        case .invalidYearlyDay:
            "年度提醒日期必须在 1 到 31 之间。"
        case .invalidYearlyDate:
            "年度提醒日期不存在。"
        case .invalidOccurrenceCount:
            "重复次数必须大于 0。"
        case .invalidRecurrenceEndDate:
            "重复结束日期不能早于首次提醒时间。"
        case .invalidFirstOccurrence:
            "提醒时间与重复规则不匹配。"
        case .startIsInThePast:
            "提醒开始时间不能早于当前时间。"
        case .searchWindowIsInThePast:
            "自动安排的时间范围不能完全落在过去。"
        }
    }
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

        let anchor: Date
        switch schedulingMode {
        case .fixed:
            guard let start else {
                throw ReminderProposalValidationError.missingStart
            }
            anchor = start
        case .findFreeTime:
            guard let searchWindow else {
                throw ReminderProposalValidationError.missingSearchWindow
            }
            anchor = searchWindow.start
        }

        if let searchWindow, searchWindow.end <= searchWindow.start {
            throw ReminderProposalValidationError.invalidSearchWindow
        }

        if schedulingMode == .findFreeTime,
           let searchWindow,
           searchWindow.end.timeIntervalSince(searchWindow.start)
               < Double(durationMinutes * 60) {
            throw ReminderProposalValidationError.searchWindowTooShort
        }

        try recurrence.validate(anchor: anchor)
        if schedulingMode == .fixed {
            try recurrence.validateFirstOccurrence(anchor)
        }
    }

    public func validateForCreation(referenceDate: Date) throws {
        try validate()

        switch schedulingMode {
        case .fixed:
            guard let start, start >= referenceDate else {
                throw ReminderProposalValidationError.startIsInThePast
            }
        case .findFreeTime:
            guard let searchWindow, searchWindow.end > referenceDate else {
                throw ReminderProposalValidationError.searchWindowIsInThePast
            }
        }
    }
}

private extension ReminderRecurrenceRule {
    func validate(anchor: Date) throws {
        switch self {
        case .once:
            break
        case let .daily(interval, end):
            try validate(interval: interval, end: end, anchor: anchor)
        case let .weekly(interval, weekdays, end):
            try validate(interval: interval, end: end, anchor: anchor)
            guard !weekdays.isEmpty else {
                throw ReminderProposalValidationError.emptyWeeklyWeekdays
            }
            guard Set(weekdays.map(\.rawValue)).count == weekdays.count else {
                throw ReminderProposalValidationError.duplicateWeeklyWeekdays
            }
        case let .monthly(interval, day, end):
            try validate(interval: interval, end: end, anchor: anchor)
            guard (1...31).contains(day) else {
                throw ReminderProposalValidationError.invalidMonthlyDay
            }
        case let .monthlyLastDay(interval, end):
            try validate(interval: interval, end: end, anchor: anchor)
        case let .yearly(interval, month, day, end):
            try validate(interval: interval, end: end, anchor: anchor)
            guard (1...12).contains(month) else {
                throw ReminderProposalValidationError.invalidYearlyMonth
            }
            guard (1...31).contains(day) else {
                throw ReminderProposalValidationError.invalidYearlyDay
            }
            guard isValidYearlyDate(month: month, day: day) else {
                throw ReminderProposalValidationError.invalidYearlyDate
            }
        }
    }

    func validate(
        interval: Int,
        end: ReminderRecurrenceEnd?,
        anchor: Date
    ) throws {
        guard interval > 0 else {
            throw ReminderProposalValidationError.invalidRecurrenceInterval
        }
        if case let .occurrenceCount(count) = end, count <= 0 {
            throw ReminderProposalValidationError.invalidOccurrenceCount
        }
        if case let .date(date) = end, date < anchor {
            throw ReminderProposalValidationError.invalidRecurrenceEndDate
        }
    }

    func isValidYearlyDate(month: Int, day: Int) -> Bool {
        let calendar = Calendar(identifier: .gregorian)
        let components = DateComponents(year: 2_000, month: month, day: day)
        guard let date = calendar.date(from: components) else {
            return false
        }
        let resolved = calendar.dateComponents([.month, .day], from: date)
        return resolved.month == month && resolved.day == day
    }

    func validateFirstOccurrence(_ start: Date) throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current

        let isValid: Bool
        switch self {
        case .once, .daily:
            isValid = true
        case let .weekly(_, weekdays, _):
            isValid = weekdays.map(\.rawValue).contains(
                calendar.component(.weekday, from: start)
            )
        case let .monthly(_, day, _):
            isValid = calendar.component(.day, from: start) == day
        case .monthlyLastDay:
            isValid = calendar.range(of: .day, in: .month, for: start)?.last
                == calendar.component(.day, from: start)
        case let .yearly(_, month, day, _):
            let components = calendar.dateComponents([.month, .day], from: start)
            isValid = components.month == month && components.day == day
        }

        guard isValid else {
            throw ReminderProposalValidationError.invalidFirstOccurrence
        }
    }
}
