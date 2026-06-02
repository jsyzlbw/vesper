import Foundation
import Testing
@testable import DiaryCompanionCore

@Test func reminderAssistantPromptDescribesConfirmationEnvelopeContract() {
    let instruction = ReminderAssistantPrompt.systemInstruction

    #expect(instruction.contains("时间或周期信息不完整"))
    #expect(instruction.contains("先追问"))
    #expect(instruction.contains("仅输出一次"))
    #expect(instruction.contains(ReminderProposalEnvelopeParser.startMarker))
    #expect(instruction.contains(ReminderProposalEnvelopeParser.endMarker))
    #expect(instruction.contains("envelope 外"))
    #expect(instruction.contains("title"))
    #expect(instruction.contains("notes"))
    #expect(instruction.contains("start"))
    #expect(instruction.contains("durationMinutes"))
    #expect(instruction.contains("recurrence"))
    #expect(instruction.contains("schedulingMode"))
    #expect(instruction.contains("searchWindow"))
    #expect(instruction.contains("notificationEnabled"))
    #expect(instruction.contains("notificationLeadMinutes"))
    #expect(instruction.contains("alarmEnabled"))
    #expect(instruction.contains("alarmLeadMinutes"))
    #expect(instruction.contains("calendarEnabled"))
    #expect(instruction.contains("ISO8601"))
    #expect(instruction.contains("时区"))
    #expect(instruction.contains("fixed"))
    #expect(instruction.contains("findFreeTime"))
    #expect(instruction.contains("自动排期"))
    #expect(instruction.contains("用户确认前"))
    #expect(instruction.contains("不得声称已创建通知或日历"))
    #expect(instruction.contains("等待卡片确认"))
    #expect(instruction.contains("不得只用自然语言询问用户是否确认"))
    #expect(instruction.contains("必须在同一条回复中输出 envelope"))
    #expect(instruction.contains("只有用户明确要求闹钟或 alarm 时，alarmEnabled 才能为 true"))
    #expect(instruction.contains(#"{"kind":"once"}"#))
    #expect(instruction.contains(#"{"kind":"daily","interval":Int,"end":End | null}"#))
    #expect(instruction.contains(#"{"kind":"weekly","interval":Int,"weekdays":[Int],"end":End | null}"#))
    #expect(instruction.contains(#"{"kind":"monthly","interval":Int,"day":Int,"end":End | null}"#))
    #expect(instruction.contains(#"{"kind":"monthlyLastDay","interval":Int,"end":End | null}"#))
    #expect(instruction.contains(#"{"kind":"yearly","interval":Int,"month":Int,"day":Int,"end":End | null}"#))
    #expect(instruction.contains(#"{"kind":"date","date":ISO8601 String}"#))
    #expect(instruction.contains(#"{"kind":"occurrenceCount","occurrenceCount":Int}"#))
    #expect(instruction.contains("fixed 要求 start"))
    #expect(instruction.contains("findFreeTime 要求 searchWindow"))
    #expect(instruction.contains("1=Sunday/周日"))
    #expect(instruction.contains("2=Monday/周一"))
    #expect(instruction.contains("3=Tuesday"))
    #expect(instruction.contains("4=Wednesday"))
    #expect(instruction.contains("5=Thursday"))
    #expect(instruction.contains("6=Friday"))
    #expect(instruction.contains("7=Saturday"))
}

@Test func reminderAssistantPromptIncludesCurrentLocalTime() {
    let timeZone = TimeZone(identifier: "Asia/Shanghai")!
    let instruction = ReminderAssistantPrompt.systemInstruction(
        now: Date(timeIntervalSince1970: 1_780_272_000),
        timeZone: timeZone
    )

    #expect(instruction.contains("当前本地时间："))
    #expect(instruction.contains("当前时区：Asia/Shanghai"))
    #expect(instruction.contains("忽略历史对话里可能出现的旧日期推断"))
    #expect(instruction.contains("不得生成已经完全落在过去的提醒提案"))
    #expect(instruction.contains(ReminderProposalEnvelopeParser.startMarker))
}

@Test func reminderAssistantPromptDefinesIndependentNotificationAndAlarmOutputs() {
    let instruction = ReminderAssistantPrompt.systemInstruction

    #expect(instruction.contains(
        "用户只要求提醒时：notificationEnabled=true，alarmEnabled=false。"
    ))
    #expect(instruction.contains(
        "用户只明确要求闹钟或 alarm 时：alarmEnabled=true，notificationEnabled=false。不得自动开启 notificationEnabled。"
    ))
    #expect(instruction.contains(
        "用户同时明确要求提醒与闹钟时：notificationEnabled=true，alarmEnabled=true。"
    ))
}
