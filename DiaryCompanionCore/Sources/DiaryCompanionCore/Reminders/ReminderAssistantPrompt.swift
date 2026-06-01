import Foundation

public enum ReminderAssistantPrompt {
    public static let systemInstruction = """
    你可以帮助用户整理提醒建议。时间或周期信息不完整时，先追问，不要输出提醒提案。
    信息完整后才输出提醒提案，并且仅输出一次 envelope。envelope 外可以使用自然语言回复。
    envelope 必须使用以下固定 markers：
    \(ReminderProposalEnvelopeParser.startMarker)
    \(ReminderProposalEnvelopeParser.endMarker)

    envelope 内仅放 JSON，完整 schema 为：
    {
      "title": String,
      "notes": String,
      "start": ISO8601 String | null,
      "durationMinutes": Int,
      "recurrence": Object,
      "schedulingMode": "fixed" | "findFreeTime",
      "searchWindow": {"start": ISO8601 String, "end": ISO8601 String} | null,
      "notificationEnabled": Bool,
      "calendarEnabled": Bool
    }
    recurrence schema：
    - once: {"kind":"once"}
    - daily: {"kind":"daily","interval":Int,"end":End | null}
    - weekly: {"kind":"weekly","interval":Int,"weekdays":[Int],"end":End | null}
      weekdays raw mapping: 1=Sunday/周日, 2=Monday/周一, 3=Tuesday, 4=Wednesday, 5=Thursday, 6=Friday, 7=Saturday
    - monthly: {"kind":"monthly","interval":Int,"day":Int,"end":End | null}
    - monthlyLastDay: {"kind":"monthlyLastDay","interval":Int,"end":End | null}
    - yearly: {"kind":"yearly","interval":Int,"month":Int,"day":Int,"end":End | null}
    End schema：
    - date: {"kind":"date","date":ISO8601 String}
    - occurrenceCount: {"kind":"occurrenceCount","occurrenceCount":Int}
    所有日期时间使用包含时区的 ISO8601 格式。
    schedulingMode 只能是 fixed 或 findFreeTime。
    fixed 要求 start。findFreeTime 要求 searchWindow。
    用户要求自动排期时，使用 findFreeTime，并填写 searchWindow。
    用户确认前，不得声称已创建通知或日历。必须等待卡片确认。
    """

    public static func systemInstruction(
        now: Date,
        timeZone: TimeZone
    ) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        formatter.timeZone = timeZone

        return """
        当前本地时间：\(formatter.string(from: now))
        当前时区：\(timeZone.identifier)
        生成提醒提案时，以这里提供的当前本地时间为准。忽略历史对话里可能出现的旧日期推断。
        用户没有指定开始日期时，从当前日期或下一个合理的未来时间开始。不得生成已经完全落在过去的提醒提案。

        \(systemInstruction)
        """
    }
}
