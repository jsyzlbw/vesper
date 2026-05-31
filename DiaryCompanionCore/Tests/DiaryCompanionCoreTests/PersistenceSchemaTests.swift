import Foundation
import SwiftData
import Testing
@testable import DiaryCompanionCore

@MainActor
@Test func inMemorySchemaStoresFirstVersionRecords() throws {
    let container = try DiaryModelContainerFactory.make(inMemory: true)
    let context = container.mainContext
    let now = Date(timeIntervalSince1970: 0)

    context.insert(ConversationRecord(title: "日常", createdAt: now, updatedAt: now))
    context.insert(MessageRecord(conversationID: UUID(), role: "user", content: "今天完成设计", createdAt: now))
    context.insert(DiaryRecord(date: now, content: "今天完成设计", tags: ["工作"]))
    context.insert(TaskRecord(title: "继续开发", notes: "", dueAt: now))
    context.insert(ReminderRecord(title: "吃药", body: "记得吃药", fireDate: now))
    context.insert(WeightRecord(date: now, kilograms: 70.5))
    context.insert(MealRecord(mealType: "早餐", date: now, detail: "咖啡和鸡蛋"))
    context.insert(MedicationRecord(name: "鱼油", date: now, status: "已服用"))
    context.insert(DailySummaryRecord(date: now, content: "完成了基础设计"))
    context.insert(ToolAuditRecord(toolName: "createTask", parameterSummaryData: Data(), decision: "allow", result: "success", createdAt: now))
    context.insert(ProviderProfileRecord(displayName: "OpenAI", presetID: "openai", baseURL: "https://api.openai.com/v1", modelName: "gpt-5", isEnabled: true))
    try context.save()

    #expect(try context.fetchCount(FetchDescriptor<ConversationRecord>()) == 1)
    #expect(try context.fetchCount(FetchDescriptor<MessageRecord>()) == 1)
    #expect(try context.fetchCount(FetchDescriptor<DiaryRecord>()) == 1)
    #expect(try context.fetchCount(FetchDescriptor<TaskRecord>()) == 1)
    #expect(try context.fetchCount(FetchDescriptor<ReminderRecord>()) == 1)
    #expect(try context.fetchCount(FetchDescriptor<WeightRecord>()) == 1)
    #expect(try context.fetchCount(FetchDescriptor<MealRecord>()) == 1)
    #expect(try context.fetchCount(FetchDescriptor<MedicationRecord>()) == 1)
    #expect(try context.fetchCount(FetchDescriptor<DailySummaryRecord>()) == 1)
    #expect(try context.fetchCount(FetchDescriptor<ToolAuditRecord>()) == 1)
    #expect(try context.fetchCount(FetchDescriptor<ProviderProfileRecord>()) == 1)
}
