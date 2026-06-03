import DiaryCompanionCore
import Foundation
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct DebugLogDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    var text: String

    init(text: String = "{}") {
        self.text = text
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents,
              let text = String(data: data, encoding: .utf8)
        else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.text = text
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(text.utf8))
    }
}

@MainActor
struct VesperDebugLogExporter {
    let context: ModelContext

    func makeDocument() throws -> DebugLogDocument {
        let payload = try makePayload()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(payload)
        return DebugLogDocument(text: String(decoding: data, as: UTF8.self))
    }

    private func makePayload() throws -> VesperDebugLogPayload {
        VesperDebugLogPayload(
            exportedAt: Date(),
            conversations: try fetch(ConversationRecord.self).map {
                .init(
                    id: $0.id,
                    title: $0.title,
                    createdAt: $0.createdAt,
                    updatedAt: $0.updatedAt
                )
            },
            messages: try fetch(MessageRecord.self).sorted { $0.createdAt < $1.createdAt }.map {
                .init(
                    id: $0.id,
                    conversationID: $0.conversationID,
                    role: $0.role,
                    content: $0.content,
                    createdAt: $0.createdAt
                )
            },
            diaryEntries: try fetch(DiaryRecord.self).map {
                .init(
                    id: $0.id,
                    date: $0.date,
                    content: $0.content,
                    tags: $0.tags,
                    sourceMessageID: $0.sourceMessageID
                )
            },
            tasks: try fetch(TaskRecord.self).map {
                .init(
                    id: $0.id,
                    title: $0.title,
                    notes: $0.notes,
                    dueAt: $0.dueAt,
                    isCompleted: $0.isCompleted,
                    sourceMessageID: $0.sourceMessageID
                )
            },
            reminders: try fetch(ReminderRecord.self).map {
                .init(
                    id: $0.id,
                    title: $0.title,
                    notes: $0.notes,
                    fireDate: $0.fireDate,
                    firstOccurrence: $0.firstOccurrence,
                    durationMinutes: $0.durationMinutes,
                    schedulingMode: $0.schedulingMode,
                    searchWindowStart: $0.searchWindowStart,
                    searchWindowEnd: $0.searchWindowEnd,
                    notificationEnabled: $0.notificationEnabled,
                    notificationLeadMinutes: $0.notificationLeadMinutes,
                    alarmEnabled: $0.alarmEnabled,
                    alarmLeadMinutes: $0.alarmLeadMinutes,
                    calendarEnabled: $0.calendarEnabled,
                    status: $0.status,
                    notificationResult: $0.notificationResult,
                    alarmResult: $0.alarmResult,
                    calendarResult: $0.calendarResult,
                    sourceMessageID: $0.sourceMessageID,
                    notificationIdentifiers: $0.notificationIdentifiers,
                    alarmIdentifiers: $0.alarmIdentifiers,
                    calendarEventIdentifier: $0.calendarEventIdentifier,
                    calendarExternalIdentifier: $0.calendarExternalIdentifier
                )
            },
            summaries: try fetch(DailySummaryRecord.self).map {
                .init(
                    id: $0.id,
                    date: $0.date,
                    content: $0.content,
                    createdAt: $0.createdAt
                )
            },
            toolAuditLogs: try fetch(ToolAuditRecord.self).map {
                .init(
                    id: $0.id,
                    toolName: $0.toolName,
                    parameterSummary: parameterSummary(from: $0),
                    decision: $0.decision,
                    result: $0.result,
                    createdAt: $0.createdAt
                )
            },
            providerProfiles: try fetch(ProviderProfileRecord.self).map {
                .init(
                    id: $0.id,
                    displayName: $0.displayName,
                    presetID: $0.presetID,
                    baseURL: $0.baseURL,
                    modelName: $0.modelName,
                    isEnabled: $0.isEnabled
                )
            }
        )
    }

    private func fetch<T: PersistentModel>(_ model: T.Type) throws -> [T] {
        try context.fetch(FetchDescriptor<T>())
    }

    private func parameterSummary(from log: ToolAuditRecord) -> [String: String] {
        (try? JSONDecoder().decode(
            [String: String].self,
            from: log.parameterSummaryData
        )) ?? [:]
    }
}

private struct VesperDebugLogPayload: Encodable {
    let exportedAt: Date
    let conversations: [Conversation]
    let messages: [Message]
    let diaryEntries: [DiaryEntry]
    let tasks: [Task]
    let reminders: [Reminder]
    let summaries: [Summary]
    let toolAuditLogs: [ToolAuditLog]
    let providerProfiles: [ProviderProfile]

    struct Conversation: Encodable {
        let id: UUID
        let title: String
        let createdAt: Date
        let updatedAt: Date
    }

    struct Message: Encodable {
        let id: UUID
        let conversationID: UUID
        let role: String
        let content: String
        let createdAt: Date
    }

    struct DiaryEntry: Encodable {
        let id: UUID
        let date: Date
        let content: String
        let tags: [String]
        let sourceMessageID: UUID?
    }

    struct Task: Encodable {
        let id: UUID
        let title: String
        let notes: String
        let dueAt: Date?
        let isCompleted: Bool
        let sourceMessageID: UUID?
    }

    struct Reminder: Encodable {
        let id: UUID
        let title: String
        let notes: String
        let fireDate: Date
        let firstOccurrence: Date?
        let durationMinutes: Int
        let schedulingMode: String
        let searchWindowStart: Date?
        let searchWindowEnd: Date?
        let notificationEnabled: Bool
        let notificationLeadMinutes: Int
        let alarmEnabled: Bool
        let alarmLeadMinutes: Int
        let calendarEnabled: Bool
        let status: String
        let notificationResult: String
        let alarmResult: String
        let calendarResult: String
        let sourceMessageID: UUID?
        let notificationIdentifiers: [String]
        let alarmIdentifiers: [String]
        let calendarEventIdentifier: String?
        let calendarExternalIdentifier: String?
    }

    struct Summary: Encodable {
        let id: UUID
        let date: Date
        let content: String
        let createdAt: Date
    }

    struct ToolAuditLog: Encodable {
        let id: UUID
        let toolName: String
        let parameterSummary: [String: String]
        let decision: String
        let result: String
        let createdAt: Date
    }

    struct ProviderProfile: Encodable {
        let id: UUID
        let displayName: String
        let presetID: String
        let baseURL: String
        let modelName: String
        let isEnabled: Bool
    }
}
