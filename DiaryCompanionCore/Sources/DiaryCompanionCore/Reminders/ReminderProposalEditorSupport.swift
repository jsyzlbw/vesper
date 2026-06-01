import Foundation

public enum ReminderProposalEditorSupport {
    public static func preparedForEditing(
        _ proposal: ReminderProposal,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> ReminderProposal {
        var prepared = proposal
        switch prepared.schedulingMode {
        case .fixed:
            if prepared.start == nil {
                prepared.start = roundedUpQuarterHour(after: now, calendar: calendar)
            }
        case .findFreeTime:
            if prepared.searchWindow == nil {
                prepared.searchWindow = ReminderSearchWindow(
                    start: now,
                    end: calendar.startOfDay(
                        for: calendar.date(byAdding: .day, value: 1, to: now)!
                    )
                )
            }
        }
        return prepared
    }

    public static func recurrenceSummary(
        _ recurrence: ReminderRecurrenceRule
    ) -> String {
        let base: String
        let end: ReminderRecurrenceEnd?
        switch recurrence {
        case .once:
            return "仅一次"
        case let .daily(interval, recurrenceEnd):
            base = interval == 1 ? "每天" : "每 \(interval) 天"
            end = recurrenceEnd
        case let .weekly(interval, weekdays, recurrenceEnd):
            let prefix = interval == 1 ? "每周" : "每 \(interval) 周"
            base = "\(prefix)，\(weekdays.map(weekdayText).joined(separator: "、"))"
            end = recurrenceEnd
        case let .monthly(interval, day, recurrenceEnd):
            let prefix = interval == 1 ? "每月" : "每 \(interval) 个月"
            base = "\(prefix) \(day) 日"
            end = recurrenceEnd
        case let .monthlyLastDay(interval, recurrenceEnd):
            let prefix = interval == 1 ? "每月" : "每 \(interval) 个月"
            base = "\(prefix)最后一天"
            end = recurrenceEnd
        case let .yearly(interval, month, day, recurrenceEnd):
            let prefix = interval == 1 ? "每年" : "每 \(interval) 年"
            base = "\(prefix) \(month) 月 \(day) 日"
            end = recurrenceEnd
        }
        guard let end else {
            return base
        }
        switch end {
        case let .date(date):
            return "\(base)，至 \(date.formatted(date: .abbreviated, time: .omitted))"
        case let .occurrenceCount(count):
            return "\(base)，持续 \(count) 次"
        }
    }

    private static func roundedUpQuarterHour(
        after date: Date,
        calendar: Calendar
    ) -> Date {
        let startOfMinute = calendar.dateInterval(of: .minute, for: date)!.start
        let minute = calendar.component(.minute, from: startOfMinute)
        let remainder = minute % 15
        guard remainder != 0 else {
            return startOfMinute
        }
        return calendar.date(
            byAdding: .minute,
            value: 15 - remainder,
            to: startOfMinute
        )!
    }

    private static func weekdayText(_ weekday: ReminderWeekday) -> String {
        switch weekday {
        case .sunday:
            "周日"
        case .monday:
            "周一"
        case .tuesday:
            "周二"
        case .wednesday:
            "周三"
        case .thursday:
            "周四"
        case .friday:
            "周五"
        case .saturday:
            "周六"
        }
    }
}
