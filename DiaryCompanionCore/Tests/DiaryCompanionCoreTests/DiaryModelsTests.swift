import Foundation
import Testing
@testable import DiaryCompanionCore

@Test func diaryEntryTracksSourceMessage() {
    let messageID = UUID()
    let entry = DiaryEntry(
        date: Date(timeIntervalSince1970: 0),
        content: "今天完成了项目设计。",
        tags: ["工作"],
        sourceMessageID: messageID
    )
    #expect(entry.sourceMessageID == messageID)
    #expect(entry.tags == ["工作"])
}

@Test func auditLogRedactsSensitiveKeys() {
    let log = ToolAuditLog(
        toolName: "configureProvider",
        parameters: [
            "provider": "openai",
            "apiKey": "sk-secret",
            "Authorization": "Bearer secret",
        ],
        decision: .allow,
        result: .success
    )
    #expect(log.parameterSummary["provider"] == "openai")
    #expect(log.parameterSummary["apiKey"] == "<redacted>")
    #expect(log.parameterSummary["Authorization"] == "<redacted>")
}
