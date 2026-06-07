import Foundation

public struct VesperCalendarEventSnapshot: Equatable, Sendable {
    public var title: String
    public var startDate: Date
    public var endDate: Date
    public var calendarTitle: String
    public var isAllDay: Bool

    public init(
        title: String,
        startDate: Date,
        endDate: Date,
        calendarTitle: String,
        isAllDay: Bool
    ) {
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.calendarTitle = calendarTitle
        self.isAllDay = isAllDay
    }
}

public struct VesperHealthSummarySnapshot: Equatable, Sendable {
    public var date: Date
    public var stepCount: Double
    public var activeEnergyKilocalories: Double
    public var exerciseMinutes: Double
    public var sleepMinutes: Double
    public var sleepInBedMinutes: Double
    public var sourceDescription: String

    public init(
        date: Date,
        stepCount: Double,
        activeEnergyKilocalories: Double,
        exerciseMinutes: Double,
        sleepMinutes: Double,
        sleepInBedMinutes: Double,
        sourceDescription: String
    ) {
        self.date = date
        self.stepCount = stepCount
        self.activeEnergyKilocalories = activeEnergyKilocalories
        self.exerciseMinutes = exerciseMinutes
        self.sleepMinutes = sleepMinutes
        self.sleepInBedMinutes = sleepInBedMinutes
        self.sourceDescription = sourceDescription
    }

    public var effectiveSleepMinutes: Double {
        sleepMinutes > 0 ? sleepMinutes : sleepInBedMinutes
    }

    public var sleepSourceNote: String {
        if sleepMinutes > 0 {
            return "asleep 睡眠记录"
        }
        if sleepInBedMinutes > 0 {
            return "没有 asleep 明细，使用卧床记录估算"
        }
        return "没有睡眠记录"
    }
}

public enum VesperLocalContextPrompt {
    public static func instruction(
        calendarSnapshots: [VesperCalendarEventSnapshot],
        healthSnapshots: [VesperHealthSummarySnapshot],
        now: Date,
        timeZone: TimeZone,
        calendar: Calendar = .current,
        localeIdentifier: String
    ) -> String {
        var scopedCalendar = calendar
        scopedCalendar.timeZone = timeZone
        let locale = Locale(identifier: localeIdentifier)

        var lines = [
            "本地上下文：这些信息来自 Vesper 已同步到本机的数据。回答、规划和追问时优先参考这些事实。",
            "不要编造没有出现在上下文里的日历、睡眠、运动或步数；如果上下文缺失，要明确说没有本地记录，而不是假装已经读取。",
            "如果这里已经列出本地摘要，不要声称读取失败；可以说明数据粒度有限。",
            "如果健康数据里睡眠来自“卧床记录估算”，可以用于粗略作息建议，但不要说这是精确 asleep 睡眠。",
            "",
            "近日/今日日历：",
        ]

        let nearbyEvents = calendarSnapshots
            .sorted { $0.startDate < $1.startDate }
            .prefix(12)
        if nearbyEvents.isEmpty {
            lines.append("- 没有本地日历摘要。")
        } else {
            lines.append(contentsOf: nearbyEvents.map {
                "- \(eventLine($0, locale: locale, displayCalendar: scopedCalendar))"
            })
        }

        lines.append("")
        lines.append("最近健康摘要：")
        let recentHealth = healthSnapshots
            .sorted { $0.date > $1.date }
            .prefix(7)
        if recentHealth.isEmpty {
            lines.append("- 最近没有本地 Health 摘要；不要编造睡眠、运动或步数。")
        } else {
            lines.append(contentsOf: recentHealth.map {
                "- \(healthLine($0, locale: locale, displayCalendar: scopedCalendar))"
            })
        }

        lines.append("")
        lines.append("当前时间参考：\(dateTime(now, locale: locale, displayCalendar: scopedCalendar))")
        return lines.joined(separator: "\n")
    }

    private static func eventLine(
        _ event: VesperCalendarEventSnapshot,
        locale: Locale,
        displayCalendar: Calendar
    ) -> String {
        if event.isAllDay {
            return "\(date(event.startDate, locale: locale, displayCalendar: displayCalendar)) 全天 · \(event.title) · \(event.calendarTitle)"
        }
        return "\(date(event.startDate, locale: locale, displayCalendar: displayCalendar)) \(time(event.startDate, locale: locale, displayCalendar: displayCalendar))-\(time(event.endDate, locale: locale, displayCalendar: displayCalendar)) · \(event.title) · \(event.calendarTitle)"
    }

    private static func healthLine(
        _ health: VesperHealthSummarySnapshot,
        locale: Locale,
        displayCalendar: Calendar
    ) -> String {
        let sleepHours = health.effectiveSleepMinutes / 60
        return "\(date(health.date, locale: locale, displayCalendar: displayCalendar)) · \(Int(health.stepCount.rounded())) 步 · \(Int(health.activeEnergyKilocalories.rounded())) 千卡活动能量 · \(Int(health.exerciseMinutes.rounded())) 分钟锻炼 · 睡眠约 \(String(format: "%.1f", sleepHours)) 小时（\(health.sleepSourceNote)） · \(health.sourceDescription)"
    }

    private static func date(
        _ value: Date,
        locale: Locale,
        displayCalendar: Calendar
    ) -> String {
        formatter(
            locale: locale,
            displayCalendar: displayCalendar,
            dateStyle: .medium,
            timeStyle: .none
        ).string(from: value)
    }

    private static func time(
        _ value: Date,
        locale: Locale,
        displayCalendar: Calendar
    ) -> String {
        formatter(
            locale: locale,
            displayCalendar: displayCalendar,
            dateStyle: .none,
            timeStyle: .short
        ).string(from: value)
    }

    private static func dateTime(
        _ value: Date,
        locale: Locale,
        displayCalendar: Calendar
    ) -> String {
        formatter(
            locale: locale,
            displayCalendar: displayCalendar,
            dateStyle: .medium,
            timeStyle: .short
        ).string(from: value)
    }

    private static func formatter(
        locale: Locale,
        displayCalendar: Calendar,
        dateStyle: DateFormatter.Style,
        timeStyle: DateFormatter.Style
    ) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.calendar = displayCalendar
        formatter.timeZone = displayCalendar.timeZone
        formatter.dateStyle = dateStyle
        formatter.timeStyle = timeStyle
        return formatter
    }
}
