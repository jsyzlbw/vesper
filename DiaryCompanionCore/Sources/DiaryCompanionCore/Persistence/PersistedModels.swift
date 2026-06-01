import Foundation
import SwiftData

@Model public final class ConversationRecord {
    @Attribute(.unique) public var id: UUID
    public var title: String
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        title: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

@Model public final class MessageRecord {
    @Attribute(.unique) public var id: UUID
    public var conversationID: UUID
    public var role: String
    public var content: String
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        conversationID: UUID,
        role: String,
        content: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.conversationID = conversationID
        self.role = role
        self.content = content
        self.createdAt = createdAt
    }
}

@Model public final class DiaryRecord {
    @Attribute(.unique) public var id: UUID
    public var date: Date
    public var content: String
    public var tags: [String]
    public var sourceMessageID: UUID?

    public init(
        id: UUID = UUID(),
        date: Date,
        content: String,
        tags: [String] = [],
        sourceMessageID: UUID? = nil
    ) {
        self.id = id
        self.date = date
        self.content = content
        self.tags = tags
        self.sourceMessageID = sourceMessageID
    }
}

@Model public final class TaskRecord {
    @Attribute(.unique) public var id: UUID
    public var title: String
    public var notes: String
    public var dueAt: Date?
    public var isCompleted: Bool
    public var sourceMessageID: UUID?

    public init(
        id: UUID = UUID(),
        title: String,
        notes: String = "",
        dueAt: Date? = nil,
        isCompleted: Bool = false,
        sourceMessageID: UUID? = nil
    ) {
        self.id = id
        self.title = title
        self.notes = notes
        self.dueAt = dueAt
        self.isCompleted = isCompleted
        self.sourceMessageID = sourceMessageID
    }
}

@Model public final class ReminderRecord {
    @Attribute(.unique) public var id: UUID
    public var taskID: UUID?
    public var title: String
    public var body: String
    public var fireDate: Date
    public var repeats: Bool
    public var isScheduled: Bool
    public var notes: String = ""
    public var firstOccurrence: Date?
    public var durationMinutes: Int = 0
    public var recurrenceData: Data = Data()
    public var schedulingMode: String = ReminderSchedulingMode.fixed.rawValue
    public var searchWindowStart: Date?
    public var searchWindowEnd: Date?
    public var notificationEnabled: Bool = false
    public var calendarEnabled: Bool = false
    public var status: String = ReminderProposalStatus.pendingConfirmation.rawValue
    public var notificationResult: String = ReminderExecutionResult.notRequested.rawValue
    public var calendarResult: String = ReminderExecutionResult.notRequested.rawValue
    public var sourceMessageID: UUID?
    public var notificationIdentifiers: [String] = []
    public var calendarEventIdentifier: String?
    public var calendarExternalIdentifier: String?

    public init(
        id: UUID = UUID(),
        taskID: UUID? = nil,
        title: String,
        body: String,
        fireDate: Date,
        repeats: Bool = false,
        isScheduled: Bool = false
    ) {
        self.id = id
        self.taskID = taskID
        self.title = title
        self.body = body
        self.fireDate = fireDate
        self.repeats = repeats
        self.isScheduled = isScheduled
        self.notes = body
        self.firstOccurrence = fireDate
        self.durationMinutes = 1
        self.recurrenceData = (try? JSONEncoder().encode(ReminderRecurrenceRule.once))
            ?? Data(#"{"once":{}}"#.utf8)
        self.schedulingMode = ReminderSchedulingMode.fixed.rawValue
        self.notificationEnabled = true
        self.calendarEnabled = false
        self.status = isScheduled
            ? ReminderProposalStatus.scheduled.rawValue
            : ReminderProposalStatus.pendingConfirmation.rawValue
        self.notificationResult = isScheduled
            ? ReminderExecutionResult.scheduled.rawValue
            : ReminderExecutionResult.notRequested.rawValue
        self.calendarResult = ReminderExecutionResult.notRequested.rawValue
    }

    public init(
        id: UUID = UUID(),
        taskID: UUID? = nil,
        title: String,
        notes: String,
        firstOccurrence: Date?,
        durationMinutes: Int,
        recurrenceData: Data,
        schedulingMode: String,
        searchWindowStart: Date?,
        searchWindowEnd: Date?,
        notificationEnabled: Bool,
        calendarEnabled: Bool,
        status: String = ReminderProposalStatus.pendingConfirmation.rawValue,
        notificationResult: String = ReminderExecutionResult.notRequested.rawValue,
        calendarResult: String = ReminderExecutionResult.notRequested.rawValue,
        sourceMessageID: UUID? = nil,
        notificationIdentifiers: [String] = [],
        calendarEventIdentifier: String? = nil,
        calendarExternalIdentifier: String? = nil
    ) {
        self.id = id
        self.taskID = taskID
        self.title = title
        self.body = notes
        self.fireDate = firstOccurrence ?? searchWindowStart ?? .distantPast
        self.repeats = false
        self.isScheduled = status == ReminderProposalStatus.scheduled.rawValue
        self.notes = notes
        self.firstOccurrence = firstOccurrence
        self.durationMinutes = durationMinutes
        self.recurrenceData = recurrenceData
        self.schedulingMode = schedulingMode
        self.searchWindowStart = searchWindowStart
        self.searchWindowEnd = searchWindowEnd
        self.notificationEnabled = notificationEnabled
        self.calendarEnabled = calendarEnabled
        self.status = status
        self.notificationResult = notificationResult
        self.calendarResult = calendarResult
        self.sourceMessageID = sourceMessageID
        self.notificationIdentifiers = notificationIdentifiers
        self.calendarEventIdentifier = calendarEventIdentifier
        self.calendarExternalIdentifier = calendarExternalIdentifier
    }
}

@Model public final class WeightRecord {
    @Attribute(.unique) public var id: UUID
    public var date: Date
    public var kilograms: Double

    public init(id: UUID = UUID(), date: Date, kilograms: Double) {
        self.id = id
        self.date = date
        self.kilograms = kilograms
    }
}

@Model public final class MealRecord {
    @Attribute(.unique) public var id: UUID
    public var mealType: String
    public var date: Date
    public var detail: String
    public var aiSuggestion: String?

    public init(
        id: UUID = UUID(),
        mealType: String,
        date: Date,
        detail: String,
        aiSuggestion: String? = nil
    ) {
        self.id = id
        self.mealType = mealType
        self.date = date
        self.detail = detail
        self.aiSuggestion = aiSuggestion
    }
}

@Model public final class MedicationRecord {
    @Attribute(.unique) public var id: UUID
    public var name: String
    public var date: Date
    public var status: String
    public var notes: String

    public init(
        id: UUID = UUID(),
        name: String,
        date: Date,
        status: String,
        notes: String = ""
    ) {
        self.id = id
        self.name = name
        self.date = date
        self.status = status
        self.notes = notes
    }
}

@Model public final class DailySummaryRecord {
    @Attribute(.unique) public var id: UUID
    public var date: Date
    public var content: String
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        date: Date,
        content: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.date = date
        self.content = content
        self.createdAt = createdAt
    }
}

@Model public final class ToolAuditRecord {
    @Attribute(.unique) public var id: UUID
    public var toolName: String
    public var parameterSummaryData: Data
    public var decision: String
    public var result: String
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        toolName: String,
        parameterSummaryData: Data,
        decision: String,
        result: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.toolName = toolName
        self.parameterSummaryData = parameterSummaryData
        self.decision = decision
        self.result = result
        self.createdAt = createdAt
    }
}

@Model public final class ProviderProfileRecord {
    @Attribute(.unique) public var id: UUID
    public var displayName: String
    public var presetID: String
    public var baseURL: String
    public var modelName: String
    public var isEnabled: Bool

    public init(
        id: UUID = UUID(),
        displayName: String,
        presetID: String,
        baseURL: String,
        modelName: String,
        isEnabled: Bool
    ) {
        self.id = id
        self.displayName = displayName
        self.presetID = presetID
        self.baseURL = baseURL
        self.modelName = modelName
        self.isEnabled = isEnabled
    }
}

public enum DiarySchema {
    public static var models: [any PersistentModel.Type] {
        [
            ConversationRecord.self,
            MessageRecord.self,
            DiaryRecord.self,
            TaskRecord.self,
            ReminderRecord.self,
            WeightRecord.self,
            MealRecord.self,
            MedicationRecord.self,
            DailySummaryRecord.self,
            ToolAuditRecord.self,
            ProviderProfileRecord.self,
        ]
    }
}
