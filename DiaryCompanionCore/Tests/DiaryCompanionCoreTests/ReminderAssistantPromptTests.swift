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
    #expect(instruction.contains("calendarEnabled"))
    #expect(instruction.contains("ISO8601"))
    #expect(instruction.contains("时区"))
    #expect(instruction.contains("fixed"))
    #expect(instruction.contains("findFreeTime"))
    #expect(instruction.contains("自动排期"))
    #expect(instruction.contains("用户确认前"))
    #expect(instruction.contains("不得声称已创建通知或日历"))
    #expect(instruction.contains("等待卡片确认"))
}
