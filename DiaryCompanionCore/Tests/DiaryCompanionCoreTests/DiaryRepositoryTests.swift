import Foundation
import Testing
@testable import DiaryCompanionCore

@MainActor
@Test func repositoryCreatesDiaryEntriesAndTasks() throws {
    let container = try DiaryModelContainerFactory.make(inMemory: true)
    let repository = DiaryRepository(context: container.mainContext)
    let now = Date(timeIntervalSince1970: 0)

    try repository.createDiaryEntry(date: now, content: "今天完成持久化", tags: ["工作"])
    try repository.createTask(title: "继续实现聊天", dueAt: now)

    #expect(try repository.fetchDiaryEntries().map(\.content) == ["今天完成持久化"])
    #expect(try repository.fetchTasks().map(\.title) == ["继续实现聊天"])
}

@MainActor
@Test func repositoryPersistsRedactedAuditLog() throws {
    let container = try DiaryModelContainerFactory.make(inMemory: true)
    let repository = DiaryRepository(context: container.mainContext)
    let log = ToolAuditLog(
        toolName: "configureProvider",
        parameters: ["provider": "openai", "apiKey": "sk-secret"],
        decision: .allow,
        result: .success
    )

    try repository.saveAuditLog(log)

    let stored = try #require(repository.fetchAuditLogs().first)
    let parameters = try JSONDecoder().decode([String: String].self, from: stored.parameterSummaryData)
    #expect(parameters["provider"] == "openai")
    #expect(parameters["apiKey"] == "<redacted>")
}
