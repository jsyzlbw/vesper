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
    var auditDescription: String { text("AI 的工具调用记录会显示在这里，用来核对它是否真的写入了日记、任务、提醒或日历。", "AI tool calls appear here so you can verify whether it really wrote diaries, tasks, reminders, or calendar events.") }
    var noTimelineRecords: String { text("暂无记录", "No records yet") }
    var timelineDescription: String { text("AI 保存的日记、任务、提醒、闹钟和总结会出现在这里。", "Diaries, tasks, reminders, alarms, and summaries saved by AI will appear here.") }
    var startConversation: String { text("开始对话", "Start a conversation") }
    var startConversationDescription: String { text("连接 AI Provider 后，通过自然语言记录生活。", "Connect an AI provider, then describe what you need in natural language.") }
    var conversationHistory: String { text("历史对话", "Conversation history") }
    var todayConversation: String { text("今天的对话", "Today's conversation") }
    func emptyConversationDescription(_ title: String) -> String {
        text(
            "\(title) 还没有消息。每天早上 4 点后，Vesper 会自动开启新的当天对话。",
            "\(title) has no messages yet. Vesper starts a new daily conversation after 4 AM."
        )
    }
    var naturalLanguagePlaceholder: String { text("输入自然语言要求", "Describe what you need") }
    var naturalLanguage: String { text("自然语言要求", "Natural language request") }
    var dismissKeyboard: String { text("收起键盘", "Dismiss keyboard") }
    var copy: String { text("复制", "Copy") }
    var delete: String { text("删除", "Delete") }
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
    var support: String { text("支持", "Support") }
    var userGuide: String { text("用户说明书", "User Guide") }
    var exportDebugLog: String { text("导出调试日志", "Export debug log") }
    var defaultPolicy: String { text("默认策略", "Default policy") }
    var confirmBeforeExecution: String { text("执行前确认", "Confirm before execution") }
    var addProvider: String { text("新增 Provider", "Add Provider") }
    var editProvider: String { text("编辑 Provider", "Edit Provider") }
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

    var journalAutomation: String { text("日记与周记", "Journal & weekly review") }
    var personalRoutine: String { text("个人常规事项", "Personal routine") }
    var personalRoutineNotes: String { text("每天必做与固定习惯", "Daily habits and fixed routines") }
    var personalRoutinePlaceholder: String {
        text(
            "例如：每天 12:00-13:00 午饭；18:30 晚饭；23:30 后不安排高强度学习；周一三五晚上健身。",
            "Example: lunch 12:00-13:00 daily; dinner at 18:30; avoid intense study after 23:30; gym on Mon/Wed/Fri evenings."
        )
    }
    var personalRoutineFooter: String {
        text(
            "这段内容会作为系统提示词的一部分，帮助 AI 安排计划时避开三餐、睡眠、通勤和你的固定习惯。",
            "This becomes part of the system prompt so AI can avoid meals, sleep, commute, and your fixed habits when planning."
        )
    }
    var dailyJournalPrompts: String { text("早晚主动对话", "Morning & evening prompts") }
    var morningPromptEnabled: String { text("早晨主动提醒", "Morning prompt") }
    var eveningPromptEnabled: String { text("晚上总结提醒", "Evening reflection") }
    var morningPromptTime: String { text("早晨时间", "Morning time") }
    var eveningPromptTime: String { text("晚上时间", "Evening time") }
    var escalationAlarm: String { text("未打开时升级闹铃", "Escalate if unopened") }
    var morningEscalationAlarm: String { text("早晨升级为闹铃", "Morning alarm escalation") }
    var eveningEscalationAlarm: String { text("晚上升级为闹铃", "Evening alarm escalation") }
    func escalationDelayMinutes(_ minutes: Int) -> String { text("等待 \(minutes) 分钟后响铃", "Ring after \(minutes) min") }
    var escalationAlarmFooter: String {
        text(
            "Vesper 会先发普通通知。如果你在等待时间内打开 App，当天对应闹铃会自动取消；否则 iOS 26+ 会使用真闹铃。",
            "Vesper sends a normal notification first. If you open the app during the waiting window, that day's alarm is cancelled; otherwise iOS 26+ uses a real alarm."
        )
    }
    var weeklySummaryEnabled: String { text("生成本周总结", "Generate weekly review") }
    var weeklySummaryWeekday: String { text("周总结星期", "Review day") }
    var weeklySummaryTime: String { text("周总结时间", "Review time") }
    var weeklySummaryFooter: String {
        text(
            "到点后 Vesper 会整理本周日程、运动和睡眠，并给出生活健康建议。",
            "At the scheduled time, Vesper summarizes calendar, activity, and sleep, then adds lifestyle and health suggestions."
        )
    }
    var importVisibleCalendars: String { text("读取所有可见日历", "Import visible calendars") }
    var importHealthData: String { text("读取运动与睡眠", "Import activity and sleep") }
    var journalAutomationFooter: String {
        text(
            "Vesper 会用本地通知主动发起对话，并在 App 打开或回到前台时同步日历、运动和睡眠数据。",
            "Vesper uses local notifications to start the conversation, then syncs calendar, activity, and sleep data when the app opens or returns to foreground."
        )
    }

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
    var restoreReminder: String { text("恢复卡片", "Restore card") }
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
    var realAlarmIOS26Footer: String { text("真闹钟会像系统闹钟一样响铃。仅支持 iOS 26 及以上，由 Vesper 管理，可能不会显示在“时钟”App 列表中；普通提醒默认不会开启。", "Real alarms ring like system alarms. They require iOS 26 or later, are managed by Vesper, and may not appear in the Clock app list. Ordinary reminders keep them off.") }
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

    var remindersAndAlarms: String { text("提醒与闹钟", "Reminders & alarms") }
    var timelineCalendar: String { text("时间线日历", "Timeline calendar") }
    var noRecordsForSelectedDate: String { text("这一天暂无记录", "No records on this day") }
    var diaryAndTasks: String { text("日记与任务", "Diaries & tasks") }
    var summaries: String { text("总结", "Summaries") }
    var journal: String { text("日记", "Journal") }
    var calendarEvents: String { text("日历事项", "Calendar events") }
    var morningJournalTitle: String { text("今日晨间简报", "Morning brief") }
    var eveningJournalTitle: String { text("今晚复盘", "Evening reflection") }
    var weeklyJournalTitle: String { text("本周回顾", "Weekly review") }
    var morningJournalNotificationBody: String { text("来看看今天的日程和身体状态。", "Review today's schedule and body snapshot.") }
    var eveningJournalNotificationBody: String { text("花一分钟总结今天，Vesper 会帮你整理。", "Spend a minute reflecting. Vesper will organize it.") }
    var weeklyJournalNotificationBody: String { text("本周总结准备好了，来看看节奏和健康建议。", "Your weekly review is ready with rhythm and health suggestions.") }
    var todayScheduleHeader: String { text("今日安排", "Today's schedule") }
    var healthSnapshotHeader: String { text("健康快照", "Health snapshot") }
    var noCalendarEventsToday: String { text("今天还没有日历事项。", "No calendar events today.") }
    var noHealthDataYet: String { text("还没有读取到 Health 数据。", "No Health data yet.") }
    var eveningReviewPrompt: String { text("今晚可以从这几件事开始：今天完成了什么、有什么情绪波动、明天最该推进什么。", "Start with what you finished, what shifted emotionally, and what matters most tomorrow.") }
    var untitledCalendarEvent: String { text("未命名日程", "Untitled event") }
    var allDay: String { text("全天", "All-day") }
    func morningAssistantMessage(_ body: String) -> String {
        text("早上好。我已经整理了今天的日程和健康快照：\n\n\(body)", "Good morning. I prepared today's schedule and health snapshot:\n\n\(body)")
    }
    func eveningAssistantMessage(_ body: String) -> String {
        text("晚上好。我们来收一下今天吧：\n\n\(body)", "Good evening. Let's gather today:\n\n\(body)")
    }
    func weeklyAssistantMessage(_ body: String) -> String {
        text("这是本周回顾和一点生活健康建议：\n\n\(body)", "Here is your weekly review and a few lifestyle-health suggestions:\n\n\(body)")
    }
    func healthSummaryLine(
        steps: Int,
        energy: Int,
        exerciseMinutes: Int,
        sleepHours: Double
    ) -> String {
        text(
            "步数 \(steps)，活动能量 \(energy) 千卡，锻炼记录 \(exerciseMinutes) 分钟，睡眠/卧床约 \(String(format: "%.1f", sleepHours)) 小时",
            "\(steps) steps, \(energy) kcal active energy, \(exerciseMinutes) min workout record, about \(String(format: "%.1f", sleepHours)) h sleep/in-bed"
        )
    }
    func weeklyJournalBody(
        eventCount: Int,
        stepCount: Int,
        sleepHours: Double,
        averageSleepHours: Double,
        exerciseMinutes: Int
    ) -> String {
        text(
            "这一周同步到 \(eventCount) 个日历事项，累计约 \(stepCount) 步，锻炼记录 \(exerciseMinutes) 分钟，睡眠/卧床记录 \(String(format: "%.1f", sleepHours)) 小时，日均约 \(String(format: "%.1f", averageSleepHours)) 小时。\n\n建议：如果日均睡眠/卧床低于 7 小时，下周先把睡前 30 分钟留给低刺激活动；如果锻炼记录少于 150 分钟，可以安排 3 次 20-30 分钟的轻运动；如果日程很多，给自己预留至少一个无安排晚间。你也可以补充本周最重要的进展、遗憾、关系和下周重点。",
            "This week Vesper synced \(eventCount) calendar events, about \(stepCount) steps, \(exerciseMinutes) workout-record minutes, and \(String(format: "%.1f", sleepHours)) hours of sleep/in-bed data, averaging about \(String(format: "%.1f", averageSleepHours)) hours per day.\n\nSuggestions: if average sleep/in-bed time is below 7 hours, protect the last 30 minutes before bed for low-stimulation time; if workout records are below 150 minutes, schedule 3 light 20-30 minute sessions; if your calendar is crowded, reserve at least one unscheduled evening. You can also add the week's key progress, regrets, relationships, and next week's focus."
        )
    }
    func weekdayName(_ weekday: Int) -> String {
        let chinese = ["周日", "周一", "周二", "周三", "周四", "周五", "周六"]
        let english = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
        let index = min(max(weekday, 1), 7) - 1
        return language == .simplifiedChinese ? chinese[index] : english[index]
    }
    var pendingConfirmation: String { text("待确认", "Pending") }
    var executing: String { text("执行中", "Executing") }
    var scheduled: String { text("已安排", "Scheduled") }
    var notificationOutput: String { text("通知", "Notification") }
    var alarmOutput: String { text("闹钟", "Alarm") }
    var calendarOutput: String { text("日历", "Calendar") }
    var noDueDate: String { text("无截止时间", "No due date") }
    var completed: String { text("已完成", "Completed") }
    var open: String { text("未完成", "Open") }
    var decision: String { text("权限决策", "Decision") }
    var result: String { text("结果", "Result") }
    var parameters: String { text("参数", "Parameters") }
    var notRequested: String { text("未请求", "Not requested") }
    var pending: String { text("等待中", "Pending") }
    var permissionDenied: String { text("权限被拒绝", "Permission denied") }
    var failed: String { text("失败", "Failed") }
    func statusLabel(_ status: ReminderProposalStatus) -> String {
        switch status {
        case .pendingConfirmation: pendingConfirmation
        case .executing: executing
        case .scheduled: scheduled
        case .cancelled: cancelled
        }
    }
    func executionResultLabel(_ rawValue: String) -> String {
        guard let result = ReminderExecutionResult(rawValue: rawValue) else {
            return rawValue
        }
        return switch result {
        case .notRequested: notRequested
        case .pending: pending
        case .scheduled: scheduled
        case .created: created
        case .permissionDenied: permissionDenied
        case .failed: failed
        }
    }
}
