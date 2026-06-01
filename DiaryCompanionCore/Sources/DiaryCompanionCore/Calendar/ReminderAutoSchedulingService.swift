import Foundation

public enum ReminderAutoSchedulingError: Error, Equatable, Sendable {
    case calendarPermissionDenied
    case noAvailableSlot
}

extension ReminderAutoSchedulingError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .calendarPermissionDenied:
            "自动排期需要读取日历，请在系统设置中允许日历访问后重试。"
        case .noAvailableSlot:
            "指定时间范围内没有足够长的空档，请换一个范围后重试。"
        }
    }
}

@MainActor
public final class ReminderAutoSchedulingService {
    private let calendarClient: CalendarClient
    private let availabilityService: CalendarAvailabilityService
    private let calendar: Calendar

    public init(
        calendarClient: CalendarClient,
        availabilityService: CalendarAvailabilityService = CalendarAvailabilityService(),
        calendar: Calendar = .current
    ) {
        self.calendarClient = calendarClient
        self.availabilityService = availabilityService
        self.calendar = calendar
    }

    public func resolve(_ proposal: ReminderProposal) async throws -> ReminderProposal {
        try proposal.validate()
        guard proposal.schedulingMode == .findFreeTime,
              let searchWindow = proposal.searchWindow
        else {
            return proposal
        }
        guard try await calendarClient.requestFullAccess() else {
            throw ReminderAutoSchedulingError.calendarPermissionDenied
        }

        let window = DateInterval(start: searchWindow.start, end: searchWindow.end)
        let busyIntervals = try await calendarClient.busyIntervals(in: window)
        guard let slot = availabilityService.firstAvailableSlot(
            within: window,
            durationMinutes: proposal.durationMinutes,
            busyIntervals: busyIntervals,
            matchingStart: { [calendar] date in
                Self.allowsFirstOccurrence(
                    date,
                    for: proposal.recurrence,
                    calendar: calendar
                )
            }
        ) else {
            throw ReminderAutoSchedulingError.noAvailableSlot
        }

        var resolved = proposal
        resolved.start = slot.start
        return resolved
    }

    nonisolated static func allowsFirstOccurrence(
        _ date: Date,
        for recurrence: ReminderRecurrenceRule,
        calendar: Calendar
    ) -> Bool {
        switch recurrence {
        case .once, .daily:
            return true
        case let .weekly(_, weekdays, _):
            return weekdays.contains {
                $0.rawValue == calendar.component(.weekday, from: date)
            }
        case let .monthly(_, day, _):
            return calendar.component(.day, from: date) == day
        case .monthlyLastDay:
            guard let range = calendar.range(of: .day, in: .month, for: date) else {
                return false
            }
            return calendar.component(.day, from: date) == range.count
        case let .yearly(_, month, day, _):
            return calendar.component(.month, from: date) == month
                && calendar.component(.day, from: date) == day
        }
    }
}
