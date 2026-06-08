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

@MainActor
@Test func defaultJournalSettingsDelayHealthImportUntilUserEnablesIt() throws {
    let container = try DiaryModelContainerFactory.make(inMemory: true)
    let repository = DiaryRepository(context: container.mainContext)

    let settings = try repository.journalSettings()

    #expect(settings.isCalendarImportEnabled == false)
    #expect(settings.isMorningPromptEnabled == false)
    #expect(settings.isEveningPromptEnabled == false)
    #expect(settings.isMorningEscalationAlarmEnabled == false)
    #expect(settings.isEveningEscalationAlarmEnabled == false)
    #expect(settings.isWeeklySummaryEnabled == false)
    #expect(settings.isHealthImportEnabled == false)
}

@MainActor
@Test func repositoryRemovesCalendarSnapshotsMissingFromLatestSyncWindow() throws {
    let container = try DiaryModelContainerFactory.make(inMemory: true)
    let repository = DiaryRepository(context: container.mainContext)
    let calendar = Calendar(identifier: .gregorian)
    let windowStart = calendar.date(from: DateComponents(year: 2026, month: 6, day: 8))!
    let deletedStart = calendar.date(from: DateComponents(year: 2026, month: 6, day: 9, hour: 9))!
    let keptStart = calendar.date(from: DateComponents(year: 2026, month: 6, day: 10, hour: 10))!
    let outsideWindowStart = calendar.date(from: DateComponents(year: 2026, month: 7, day: 20, hour: 10))!

    try repository.upsertCalendarEventSnapshot(
        eventIdentifier: "deleted-event",
        externalIdentifier: nil,
        title: "已删除日程",
        notes: "",
        startDate: deletedStart,
        endDate: deletedStart.addingTimeInterval(3_600),
        calendarTitle: "Work",
        isAllDay: false
    )
    try repository.upsertCalendarEventSnapshot(
        eventIdentifier: "kept-event",
        externalIdentifier: nil,
        title: "保留日程",
        notes: "",
        startDate: keptStart,
        endDate: keptStart.addingTimeInterval(3_600),
        calendarTitle: "Work",
        isAllDay: false
    )
    try repository.upsertCalendarEventSnapshot(
        eventIdentifier: "outside-window",
        externalIdentifier: nil,
        title: "窗口外历史",
        notes: "",
        startDate: outsideWindowStart,
        endDate: outsideWindowStart.addingTimeInterval(3_600),
        calendarTitle: "Work",
        isAllDay: false
    )

    try repository.deleteCalendarEventSnapshots(
        from: windowStart,
        to: calendar.date(byAdding: .day, value: 21, to: windowStart)!,
        excludingEventIdentifiers: ["kept-event"]
    )

    let titles = try repository.fetchCalendarEventSnapshots().map(\.title)
    #expect(!titles.contains("已删除日程"))
    #expect(titles.contains("保留日程"))
    #expect(titles.contains("窗口外历史"))
}
