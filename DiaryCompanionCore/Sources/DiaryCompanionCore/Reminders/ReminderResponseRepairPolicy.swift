import Foundation

public struct ReminderResponseRepairPolicy: Sendable {
    public init() {}

    public func shouldRequestStructuredProposal(
        latestUserText: String,
        assistantText: String,
        hasProposal: Bool
    ) -> Bool {
        guard !hasProposal else {
            return false
        }

        let combined = "\(latestUserText)\n\(assistantText)".lowercased()
        let mentionsReminder = [
            "提醒", "闹钟", "alarm", "remind", "reminder", "notification",
        ].contains { combined.contains($0) }
        let prematurelyActs = [
            "是否创建", "请确认", "成功创建", "已创建", "会准时响铃",
            "confirm whether", "please confirm", "successfully created",
            "has been created", "will ring",
        ].contains { combined.contains($0) }

        return mentionsReminder && prematurelyActs
    }

    public func correctionPrompt(previousError: Error? = nil) -> String {
        let errorContext = previousError.map {
            "\nThe previous structured proposal was invalid: \(String(describing: $0))"
        } ?? ""
        return """
        Your previous reply did not follow the reminder proposal contract.\(errorContext)
        Do not claim that any reminder, alarm, notification, or calendar event has been created.
        If the reminder details are complete, reply again with the required reminder proposal envelope(s) so the app can show confirmation cards. For multi-item plans, output one envelope per item, sorted by start time.
        If details are incomplete, ask one concise clarification question.
        """
    }

    public func safeFallback(language: VesperSupportedLanguage) -> String {
        language == .simplifiedChinese
            ? "提醒尚未创建。我没能生成可确认的提醒卡片，请重新描述时间和提醒方式。"
            : "The reminder has not been created. I couldn't generate a confirmation card; describe the time and reminder method again."
    }
}
