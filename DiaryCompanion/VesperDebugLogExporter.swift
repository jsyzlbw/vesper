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
                    logicalDay: $0.logicalDay,
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
            journalSettings: try fetch(JournalSettingsRecord.self).map {
                .init(
                    id: $0.id,
                    morningHour: $0.morningHour,
                    morningMinute: $0.morningMinute,
                    eveningHour: $0.eveningHour,
                    eveningMinute: $0.eveningMinute,
                    isMorningPromptEnabled: $0.isMorningPromptEnabled,
                    isEveningPromptEnabled: $0.isEveningPromptEnabled,
                    isMorningEscalationAlarmEnabled: $0.isMorningEscalationAlarmEnabled,
                    isEveningEscalationAlarmEnabled: $0.isEveningEscalationAlarmEnabled,
                    escalationDelayMinutes: $0.escalationDelayMinutes,
                    isWeeklySummaryEnabled: $0.isWeeklySummaryEnabled,
                    weeklySummaryWeekday: $0.weeklySummaryWeekday,
                    weeklySummaryHour: $0.weeklySummaryHour,
                    weeklySummaryMinute: $0.weeklySummaryMinute,
                    isCalendarImportEnabled: $0.isCalendarImportEnabled,
                    isHealthImportEnabled: $0.isHealthImportEnabled,
                    lastMorningPromptDate: $0.lastMorningPromptDate,
                    lastEveningPromptDate: $0.lastEveningPromptDate,
                    lastWeeklySummaryDate: $0.lastWeeklySummaryDate,
                    updatedAt: $0.updatedAt
                )
            },
            journals: try fetch(JournalRecord.self).map {
                .init(
                    id: $0.id,
                    kind: $0.kind,
                    date: $0.date,
                    title: $0.title,
                    body: $0.body,
                    createdAt: $0.createdAt,
                    updatedAt: $0.updatedAt
                )
            },
            calendarEventSnapshots: try fetch(CalendarEventSnapshotRecord.self).map {
                .init(
                    id: $0.id,
                    eventIdentifier: $0.eventIdentifier,
                    externalIdentifier: $0.externalIdentifier,
                    title: $0.title,
                    notes: $0.notes,
                    startDate: $0.startDate,
                    endDate: $0.endDate,
                    calendarTitle: $0.calendarTitle,
                    isAllDay: $0.isAllDay,
                    lastSeenAt: $0.lastSeenAt
                )
            },
            healthDailySummaries: try fetch(HealthDailySummaryRecord.self).map {
                .init(
                    id: $0.id,
                    date: $0.date,
                    stepCount: $0.stepCount,
                    activeEnergyKilocalories: $0.activeEnergyKilocalories,
                    exerciseMinutes: $0.exerciseMinutes,
                    sleepMinutes: $0.sleepMinutes,
                    sleepInBedMinutes: $0.sleepInBedMinutes,
                    sourceDescription: $0.sourceDescription,
                    updatedAt: $0.updatedAt
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
    let journalSettings: [JournalSettings]
    let journals: [Journal]
    let calendarEventSnapshots: [CalendarEventSnapshot]
    let healthDailySummaries: [HealthDailySummary]
    let toolAuditLogs: [ToolAuditLog]
    let providerProfiles: [ProviderProfile]

    struct Conversation: Encodable {
        let id: UUID
        let title: String
        let logicalDay: Date?
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

    struct JournalSettings: Encodable {
        let id: UUID
        let morningHour: Int
        let morningMinute: Int
        let eveningHour: Int
        let eveningMinute: Int
        let isMorningPromptEnabled: Bool
        let isEveningPromptEnabled: Bool
        let isMorningEscalationAlarmEnabled: Bool
        let isEveningEscalationAlarmEnabled: Bool
        let escalationDelayMinutes: Int
        let isWeeklySummaryEnabled: Bool
        let weeklySummaryWeekday: Int
        let weeklySummaryHour: Int
        let weeklySummaryMinute: Int
        let isCalendarImportEnabled: Bool
        let isHealthImportEnabled: Bool
        let lastMorningPromptDate: Date?
        let lastEveningPromptDate: Date?
        let lastWeeklySummaryDate: Date?
        let updatedAt: Date
    }

    struct Journal: Encodable {
        let id: UUID
        let kind: String
        let date: Date
        let title: String
        let body: String
        let createdAt: Date
        let updatedAt: Date
    }

    struct CalendarEventSnapshot: Encodable {
        let id: UUID
        let eventIdentifier: String
        let externalIdentifier: String?
        let title: String
        let notes: String
        let startDate: Date
        let endDate: Date
        let calendarTitle: String
        let isAllDay: Bool
        let lastSeenAt: Date
    }

    struct HealthDailySummary: Encodable {
        let id: UUID
        let date: Date
        let stepCount: Double
        let activeEnergyKilocalories: Double
        let exerciseMinutes: Double
        let sleepMinutes: Double
        let sleepInBedMinutes: Double
        let sourceDescription: String
        let updatedAt: Date
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
