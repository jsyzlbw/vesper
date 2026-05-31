import Foundation
import SwiftData

@MainActor
public final class DiaryRepository {
    private let context: ModelContext

    public init(context: ModelContext) {
        self.context = context
    }

    @discardableResult
    public func createDiaryEntry(
        date: Date,
        content: String,
        tags: [String] = [],
        sourceMessageID: UUID? = nil
    ) throws -> DiaryRecord {
        let record = DiaryRecord(
            date: date,
            content: content,
            tags: tags,
            sourceMessageID: sourceMessageID
        )
        context.insert(record)
        try context.save()
        return record
    }

    @discardableResult
    public func createTask(
        title: String,
        notes: String = "",
        dueAt: Date? = nil,
        sourceMessageID: UUID? = nil
    ) throws -> TaskRecord {
        let record = TaskRecord(
            title: title,
            notes: notes,
            dueAt: dueAt,
            sourceMessageID: sourceMessageID
        )
        context.insert(record)
        try context.save()
        return record
    }

    public func saveAuditLog(_ log: ToolAuditLog) throws {
        let data = try JSONEncoder().encode(log.parameterSummary)
        context.insert(
            ToolAuditRecord(
                id: log.id,
                toolName: log.toolName,
                parameterSummaryData: data,
                decision: log.decision.rawValue,
                result: log.result.rawValue,
                createdAt: log.createdAt
            )
        )
        try context.save()
    }

    public func fetchDiaryEntries() throws -> [DiaryRecord] {
        var descriptor = FetchDescriptor<DiaryRecord>()
        descriptor.sortBy = [SortDescriptor(\.date, order: .reverse)]
        return try context.fetch(descriptor)
    }

    public func fetchTasks() throws -> [TaskRecord] {
        var descriptor = FetchDescriptor<TaskRecord>()
        descriptor.sortBy = [SortDescriptor(\.dueAt)]
        return try context.fetch(descriptor)
    }

    public func fetchAuditLogs() throws -> [ToolAuditRecord] {
        var descriptor = FetchDescriptor<ToolAuditRecord>()
        descriptor.sortBy = [SortDescriptor(\.createdAt, order: .reverse)]
        return try context.fetch(descriptor)
    }
}
