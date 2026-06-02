import DiaryCompanionCore
import SwiftUI

struct VesperLocalizationContext {
    let language: VesperSupportedLanguage

    var locale: Locale {
        Locale(identifier: language == .simplifiedChinese ? "zh_Hans_CN" : "en_US")
    }

    var strings: VesperStrings {
        VesperStrings(language: language)
    }
}

private struct VesperLocalizationContextKey: EnvironmentKey {
    static let defaultValue = VesperLocalizationContext(language: .english)
}

extension EnvironmentValues {
    var vesperLocalization: VesperLocalizationContext {
        get { self[VesperLocalizationContextKey.self] }
        set { self[VesperLocalizationContextKey.self] = newValue }
    }
}

struct VesperStrings {
    let language: VesperSupportedLanguage

    private func text(_ chinese: String, _ english: String) -> String {
        language == .simplifiedChinese ? chinese : english
    }

    var chat: String { text("对话", "Chat") }
    var timeline: String { text("时间线", "Timeline") }
    var settings: String { text("设置", "Settings") }
    var audit: String { text("审计", "Audit") }
    var noAuditRecords: String { text("暂无审计记录", "No audit records") }
    var auditDescription: String { text("AI 的工具调用记录会显示在这里。", "AI tool calls will appear here.") }
    var noTimelineRecords: String { text("暂无记录", "No records yet") }
    var timelineDescription: String { text("AI 保存的日记、任务和总结会出现在这里。", "Diaries, tasks, and summaries saved by AI will appear here.") }
    var startConversation: String { text("开始对话", "Start a conversation") }
    var startConversationDescription: String { text("连接 AI Provider 后，通过自然语言记录生活。", "Connect an AI provider, then describe what you need in natural language.") }
    var naturalLanguagePlaceholder: String { text("输入自然语言要求", "Describe what you need") }
    var sendFailed: String { text("发送失败", "Send failed") }
    var ok: String { text("好", "OK") }
    var connectingProvider: String { text("正在连接 AI Provider", "Connecting to AI provider") }
    var generatingReply: String { text("正在生成回复", "Generating reply") }
    var thinking: String { text("正在思考", "Thinking") }
    var noSupportedProvider: String { text("请先在设置中添加并启用 DeepSeek、硅基流动或 Custom Provider。", "Add and enable DeepSeek, SiliconFlow, or a custom provider in Settings first.") }
    var missingAPIKey: String { text("当前 Provider 没有可用的 API Key，请在设置中重新保存。", "The current provider has no usable API key. Save it again in Settings.") }
    func invalidStoredRole(_ role: String) -> String { text("本地消息角色无效：\(role)", "Invalid stored message role: \(role)") }

    var aiProvider: String { "AI Provider" }
    var notConfigured: String { text("尚未配置", "Not configured") }
    var appLanguage: String { text("App 语言", "App Language") }
    var permissions: String { text("权限", "Permissions") }
    var defaultPolicy: String { text("默认策略", "Default policy") }
    var confirmBeforeExecution: String { text("执行前确认", "Confirm before execution") }
    var addProvider: String { text("新增 Provider", "Add Provider") }
    var operationFailed: String { text("操作失败", "Operation failed") }
    var provider: String { "Provider" }
    var platform: String { text("平台", "Platform") }
    var displayName: String { text("显示名称", "Display name") }
    var baseURL: String { text("Base URL（基础地址）", "Base URL") }
    var actualEndpoint: String { text("实际 Endpoint", "Resolved endpoint") }
    var modelName: String { text("模型名称", "Model name") }
    var enabled: String { text("启用", "Enabled") }
    var testConnection: String { text("测试连接", "Test connection") }
    var endpointFooter: String { text("Base URL 是服务基础地址。应用会自动追加平台对应路径，例如 DeepSeek 会请求 /chat/completions。", "Base URL is the service root. Vesper appends the provider-specific path automatically, such as /chat/completions for DeepSeek.") }
    var cancel: String { text("取消", "Cancel") }
    var save: String { text("保存", "Save") }
    var invalidConfiguration: String { text("请先填写有效配置", "Enter a valid configuration first") }
    func connectionSucceeded(_ preview: String) -> String { text("连接成功：\(preview)", "Connected: \(preview)") }
    func connectionFailed(_ message: String) -> String { text("连接失败：\(message)", "Connection failed: \(message)") }
    func required(_ field: String) -> String { text("\(field)不能为空。", "\(field) cannot be empty.") }
    var invalidBaseURL: String { text("请输入有效的 HTTP 或 HTTPS Base URL。", "Enter a valid HTTP or HTTPS Base URL.") }

    var followSystem: String { text("跟随系统", "Follow System") }
    var simplifiedChinese: String { "简体中文" }
    var english: String { "English" }
    func languageName(_ option: VesperLanguage) -> String {
        switch option {
        case .followSystem: followSystem
        case .simplifiedChinese: simplifiedChinese
        case .english: english
        }
    }

    var suggestedReminder: String { text("AI 建议创建提醒", "AI suggested reminder") }
    var creatingReminder: String { text("正在创建提醒", "Creating reminder") }
    var reminderCreated: String { text("提醒已创建", "Reminder created") }
    var reminderCancelled: String { text("提醒已取消", "Reminder cancelled") }
    var invalidReminderStatus: String { text("提醒状态异常", "Invalid reminder status") }
    var schedulingMode: String { text("安排方式", "Schedule") }
    var reminderTime: String { text("事件时间", "Event time") }
    var eventTime: String { text("事件时间", "Event time") }
    var notificationTime: String { text("通知时间", "Notification time") }
    var realAlarm: String { text("真闹钟", "Real alarm") }
    var alarmTime: String { text("闹钟时间", "Alarm time") }
    var recurrence: String { text("重复规则", "Repeat") }
    var eventDuration: String { text("事件持续时间", "Duration") }
    var systemNotification: String { text("系统通知", "Notification") }
    var addToCalendar: String { text("同步到日历", "Add to calendar") }
    var on: String { text("开启", "On") }
    var off: String { text("关闭", "Off") }
    var waitingForAutomaticPlacement: String { text("正在等待自动排期", "Waiting for automatic scheduling") }
    var interruptedCreation: String { text("创建被中断，可恢复后重试", "Creation was interrupted. Recover to retry.") }
    var recover: String { text("恢复", "Recover") }
    var created: String { text("已创建", "Created") }
    var cancelReminder: String { text("取消提醒", "Cancel reminder") }
    var cancelled: String { text("已取消", "Cancelled") }
    var confirmCreation: String { text("确认创建", "Create reminder") }
    var automaticScheduling: String { text("自动安排到空闲时间", "Find a free time") }
    var fixedTime: String { text("固定时间", "Fixed time") }
    var waitingForTime: String { text("等待补充时间", "Waiting for a time") }
    var repeatingReminder: String { text("重复提醒", "Repeating reminder") }
    var once: String { text("仅一次", "Once") }
    func durationMinutes(_ minutes: Int) -> String { text("\(minutes) 分钟", "\(minutes) min") }
    func automaticRange(_ start: String, _ end: String) -> String { text("自动安排：\(start) - \(end)", "Automatic: \(start) - \(end)") }

    var editReminder: String { text("编辑提醒", "Edit reminder") }
    var reminderContent: String { text("提醒内容", "Reminder") }
    var title: String { text("标题", "Title") }
    var notes: String { text("备注", "Notes") }
    var rangeStart: String { text("范围开始", "Window starts") }
    var rangeEnd: String { text("范围结束", "Window ends") }
    var automaticSchedulingFooter: String { text("保存后会读取所有可见日历，并选择最早可用时段。", "After saving, Vesper reads all visible calendars and selects the earliest available slot.") }
    var frequency: String { text("频率", "Frequency") }
    var limitOccurrences: String { text("限制重复次数", "Limit occurrences") }
    var createOutputs: String { text("创建内容", "Create") }
    var soundAndVibration: String { text("系统通知（声音与震动）", "Notification (sound and vibration)") }
    var realAlarmIOS26Footer: String { text("真闹钟会像系统闹钟一样响铃。仅支持 iOS 26 及以上；普通提醒默认不会开启。", "Real alarms ring like system alarms. They require iOS 26 or later and stay off for ordinary reminders.") }
    func durationStepper(_ minutes: Int) -> String { text("事件持续时间：\(minutes) 分钟", "Duration: \(minutes) min") }
    func minutesBeforeEvent(_ minutes: Int) -> String { text("通知提前：\(minutes) 分钟", "Notify \(minutes) min before") }
    func alarmMinutesBeforeEvent(_ minutes: Int) -> String { text("闹钟提前：\(minutes) 分钟", "Alarm \(minutes) min before") }
    func outputTime(_ time: String, minutesBefore: Int) -> String {
        minutesBefore == 0
            ? time
            : text("\(time)（提前 \(minutesBefore) 分钟）", "\(time) (\(minutesBefore) min before)")
    }
    func interval(_ value: Int) -> String { text("间隔：\(value)", "Interval: \(value)") }
    func totalOccurrences(_ value: Int) -> String { text("总次数：\(value)", "Occurrences: \(value)") }
    func recurrenceOccurrences(_ value: Int) -> String { text("持续 \(value) 次", "\(value) occurrences") }
    func recurrenceUntil(_ date: String) -> String { text("截止 \(date)", "until \(date)") }
    func monthlyDay(_ day: Int) -> String { text("每月第 \(day) 日", "Day \(day) of each month") }
    func month(_ month: Int) -> String { text("月份：\(month)", "Month: \(month)") }
    func day(_ day: Int) -> String { text("日期：\(day)", "Day: \(day)") }
    var daily: String { text("每天", "Daily") }
    var weekly: String { text("每周", "Weekly") }
    var monthly: String { text("每月指定日期", "Monthly on a date") }
    var monthlyLastDay: String { text("每月最后一天", "Last day of each month") }
    var yearly: String { text("每年", "Yearly") }
    func weekday(_ weekday: ReminderWeekday) -> String {
        let chinese = ["周日", "周一", "周二", "周三", "周四", "周五", "周六"]
        let english = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
        return language == .simplifiedChinese
            ? chinese[weekday.rawValue - 1]
            : english[weekday.rawValue - 1]
    }
}
