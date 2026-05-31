import Foundation
import SwiftData
import Testing
@testable import DiaryCompanionCore

@MainActor
@Test func automaticDiaryToolCreatesEntryAndSuccessAudit() throws {
    let fixture = try ToolExecutorFixture()
    let repository = fixture.repository
    var policy = ToolPermissionPolicy()
    policy.capabilityModes[.diary] = .automatic
    let executor = AssistantToolExecutor(repository: repository, policy: policy)
    let date = Date(timeIntervalSince1970: 100)

    let outcome = try executor.execute(
        .createDiaryEntry(
            date: date,
            content: "今天跑了三公里",
            tags: ["运动"],
            sourceMessageID: nil
        )
    )

    #expect(outcome == .executed)
    #expect(try repository.fetchDiaryEntries().map(\.content) == ["今天跑了三公里"])
    let audit = try #require(repository.fetchAuditLogs().first)
    #expect(audit.toolName == DiaryTool.createDiaryEntry.rawValue)
    #expect(audit.decision == ToolPermissionDecision.allow.rawValue)
    #expect(audit.result == ToolExecutionResult.success.rawValue)
}

@MainActor
@Test func defaultTaskToolRequiresConfirmationWithoutWriting() throws {
    let fixture = try ToolExecutorFixture()
    let repository = fixture.repository
    let executor = AssistantToolExecutor(
        repository: repository,
        policy: ToolPermissionPolicy()
    )

    let outcome = try executor.execute(
        .createTask(
            title: "明天交作业",
            notes: "",
            dueAt: nil,
            sourceMessageID: nil
        )
    )

    #expect(outcome == .confirmationRequired)
    #expect(try repository.fetchTasks().isEmpty)
    let audit = try #require(repository.fetchAuditLogs().first)
    #expect(audit.decision == ToolPermissionDecision.confirm.rawValue)
    #expect(audit.result == ToolExecutionResult.pendingConfirmation.rawValue)
}

@MainActor
@Test func deniedTaskToolDoesNotWrite() throws {
    let fixture = try ToolExecutorFixture()
    let repository = fixture.repository
    var policy = ToolPermissionPolicy()
    policy.capabilityModes[.task] = .denied
    let executor = AssistantToolExecutor(repository: repository, policy: policy)

    let outcome = try executor.execute(
        .createTask(
            title: "不应保存",
            notes: "",
            dueAt: nil,
            sourceMessageID: nil
        )
    )

    #expect(outcome == .denied)
    #expect(try repository.fetchTasks().isEmpty)
    let audit = try #require(repository.fetchAuditLogs().first)
    #expect(audit.decision == ToolPermissionDecision.deny.rawValue)
    #expect(audit.result == ToolExecutionResult.denied.rawValue)
}

@MainActor
@Test func confirmedTaskToolWritesAndAuditsSuccess() throws {
    let fixture = try ToolExecutorFixture()
    let repository = fixture.repository
    let executor = AssistantToolExecutor(
        repository: repository,
        policy: ToolPermissionPolicy()
    )

    let outcome = try executor.executeConfirmed(
        .createTask(
            title: "明天交作业",
            notes: "数学",
            dueAt: nil,
            sourceMessageID: nil
        )
    )

    #expect(outcome == .executed)
    #expect(try repository.fetchTasks().map(\.title) == ["明天交作业"])
    let audit = try #require(repository.fetchAuditLogs().first)
    #expect(audit.decision == ToolPermissionDecision.confirm.rawValue)
    #expect(audit.result == ToolExecutionResult.success.rawValue)
}

@MainActor
private struct ToolExecutorFixture {
    let container: ModelContainer
    let repository: DiaryRepository

    init() throws {
        container = try DiaryModelContainerFactory.make(inMemory: true)
        repository = DiaryRepository(context: container.mainContext)
    }
}
