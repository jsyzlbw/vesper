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
    public var workoutSummary: String
    public var averageHeartRate: Double
    public var maxHeartRate: Double
    public var sourceDescription: String

    public init(
        date: Date,
        stepCount: Double,
        activeEnergyKilocalories: Double,
        exerciseMinutes: Double,
        sleepMinutes: Double,
        sleepInBedMinutes: Double,
        workoutSummary: String = "",
        averageHeartRate: Double = 0,
        maxHeartRate: Double = 0,
        sourceDescription: String
    ) {
        self.date = date
        self.stepCount = stepCount
        self.activeEnergyKilocalories = activeEnergyKilocalories
        self.exerciseMinutes = exerciseMinutes
        self.sleepMinutes = sleepMinutes
        self.sleepInBedMinutes = sleepInBedMinutes
        self.workoutSummary = workoutSummary
        self.averageHeartRate = averageHeartRate
        self.maxHeartRate = maxHeartRate
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

    public var hasUsableHealthSignals: Bool {
        stepCount > 0
            || activeEnergyKilocalories > 0
            || exerciseMinutes > 0
            || sleepMinutes > 0
            || sleepInBedMinutes > 0
            || !workoutSummary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || averageHeartRate > 0
            || maxHeartRate > 0
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
            "分析运动时要综合步数、活动能量、锻炼/体能训练记录、具体项目和心率；不要只看锻炼分钟是否为 0。",
            "",
            "近日/今日日历：",
        ]

        let calendarWindowStart = scopedCalendar.startOfDay(for: now)
        let calendarWindowEnd = scopedCalendar.date(
            byAdding: .day,
            value: 21,
            to: calendarWindowStart
        ) ?? now.addingTimeInterval(21 * 24 * 60 * 60)
        let nearbyEvents = calendarSnapshots
            .filter {
                $0.endDate >= calendarWindowStart && $0.startDate < calendarWindowEnd
            }
            .sorted { $0.startDate < $1.startDate }
            .prefix(18)
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
            .filter(\.hasUsableHealthSignals)
            .sorted { $0.date > $1.date }
            .prefix(7)
        if recentHealth.isEmpty {
            if healthSnapshots.isEmpty {
                lines.append("- 最近没有本地 Health 摘要；不要编造睡眠、运动或步数。")
            } else {
                lines.append("- 最近没有可用的本地 Health 指标；可能尚未授权、设备没有同步，或 HealthKit 返回空样本。不要把这些空样本解读为用户没有运动或没有睡觉。")
            }
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
        var parts = [
            "\(date(health.date, locale: locale, displayCalendar: displayCalendar))",
            "\(Int(health.stepCount.rounded())) 步",
            "\(Int(health.activeEnergyKilocalories.rounded())) 千卡活动能量",
            "\(Int(health.exerciseMinutes.rounded())) 分钟锻炼/体能训练记录",
        ]
        if !health.workoutSummary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            parts.append("项目：\(health.workoutSummary)")
        }
        if health.averageHeartRate > 0 {
            parts.append("平均心率 \(Int(health.averageHeartRate.rounded())) bpm")
        }
        if health.maxHeartRate > 0 {
            parts.append("最高心率 \(Int(health.maxHeartRate.rounded())) bpm")
        }
        parts.append("睡眠约 \(String(format: "%.1f", sleepHours)) 小时（\(health.sleepSourceNote)）")
        parts.append(health.sourceDescription)
        return parts.joined(separator: " · ")
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
