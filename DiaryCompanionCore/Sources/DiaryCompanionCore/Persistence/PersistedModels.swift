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
    public var notificationLeadMinutes: Int = 0
    public var alarmEnabled: Bool = false
    public var alarmLeadMinutes: Int = 0
    public var calendarEnabled: Bool = false
    public var status: String = ReminderProposalStatus.pendingConfirmation.rawValue
    public var notificationResult: String = ReminderExecutionResult.notRequested.rawValue
    public var alarmResult: String = ReminderExecutionResult.notRequested.rawValue
    public var calendarResult: String = ReminderExecutionResult.notRequested.rawValue
    public var sourceMessageID: UUID?
    public var notificationIdentifiers: [String] = []
    public var alarmIdentifiers: [String] = []
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
        self.notificationLeadMinutes = 0
        self.alarmEnabled = false
        self.alarmLeadMinutes = 0
        self.calendarEnabled = false
        self.status = isScheduled
            ? ReminderProposalStatus.scheduled.rawValue
            : ReminderProposalStatus.pendingConfirmation.rawValue
        self.notificationResult = isScheduled
            ? ReminderExecutionResult.scheduled.rawValue
            : ReminderExecutionResult.notRequested.rawValue
        self.alarmResult = ReminderExecutionResult.notRequested.rawValue
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
        notificationLeadMinutes: Int = 0,
        alarmEnabled: Bool = false,
        alarmLeadMinutes: Int = 0,
        calendarEnabled: Bool,
        status: String = ReminderProposalStatus.pendingConfirmation.rawValue,
        notificationResult: String = ReminderExecutionResult.notRequested.rawValue,
        alarmResult: String = ReminderExecutionResult.notRequested.rawValue,
        calendarResult: String = ReminderExecutionResult.notRequested.rawValue,
        sourceMessageID: UUID? = nil,
        notificationIdentifiers: [String] = [],
        alarmIdentifiers: [String] = [],
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
        self.notificationLeadMinutes = notificationLeadMinutes
        self.alarmEnabled = alarmEnabled
        self.alarmLeadMinutes = alarmLeadMinutes
        self.calendarEnabled = calendarEnabled
        self.status = status
        self.notificationResult = notificationResult
        self.alarmResult = alarmResult
        self.calendarResult = calendarResult
        self.sourceMessageID = sourceMessageID
        self.notificationIdentifiers = notificationIdentifiers
        self.alarmIdentifiers = alarmIdentifiers
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

@Model public final class JournalSettingsRecord {
    @Attribute(.unique) public var id: UUID
    public var morningHour: Int = 8
    public var morningMinute: Int = 0
    public var eveningHour: Int = 21
    public var eveningMinute: Int = 30
    public var isMorningPromptEnabled: Bool = true
    public var isEveningPromptEnabled: Bool = true
    public var isMorningEscalationAlarmEnabled: Bool = true
    public var isEveningEscalationAlarmEnabled: Bool = true
    public var escalationDelayMinutes: Int = 15
    public var isWeeklySummaryEnabled: Bool = true
    public var weeklySummaryWeekday: Int = 1
    public var weeklySummaryHour: Int = 20
    public var weeklySummaryMinute: Int = 0
    public var isCalendarImportEnabled: Bool = true
    public var isHealthImportEnabled: Bool = true
    public var lastMorningPromptDate: Date?
    public var lastEveningPromptDate: Date?
    public var lastWeeklySummaryDate: Date?
    public var updatedAt: Date

    public init(
        id: UUID = UUID(uuidString: "00000000-0000-0000-0000-000000000101")!,
        morningHour: Int = 8,
        morningMinute: Int = 0,
        eveningHour: Int = 21,
        eveningMinute: Int = 30,
        isMorningPromptEnabled: Bool = true,
        isEveningPromptEnabled: Bool = true,
        isMorningEscalationAlarmEnabled: Bool = true,
        isEveningEscalationAlarmEnabled: Bool = true,
        escalationDelayMinutes: Int = 15,
        isWeeklySummaryEnabled: Bool = true,
        weeklySummaryWeekday: Int = 1,
        weeklySummaryHour: Int = 20,
        weeklySummaryMinute: Int = 0,
        isCalendarImportEnabled: Bool = true,
        isHealthImportEnabled: Bool = true,
        lastMorningPromptDate: Date? = nil,
        lastEveningPromptDate: Date? = nil,
        lastWeeklySummaryDate: Date? = nil,
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.morningHour = morningHour
        self.morningMinute = morningMinute
        self.eveningHour = eveningHour
        self.eveningMinute = eveningMinute
        self.isMorningPromptEnabled = isMorningPromptEnabled
        self.isEveningPromptEnabled = isEveningPromptEnabled
        self.isMorningEscalationAlarmEnabled = isMorningEscalationAlarmEnabled
        self.isEveningEscalationAlarmEnabled = isEveningEscalationAlarmEnabled
        self.escalationDelayMinutes = escalationDelayMinutes
        self.isWeeklySummaryEnabled = isWeeklySummaryEnabled
        self.weeklySummaryWeekday = weeklySummaryWeekday
        self.weeklySummaryHour = weeklySummaryHour
        self.weeklySummaryMinute = weeklySummaryMinute
        self.isCalendarImportEnabled = isCalendarImportEnabled
        self.isHealthImportEnabled = isHealthImportEnabled
        self.lastMorningPromptDate = lastMorningPromptDate
        self.lastEveningPromptDate = lastEveningPromptDate
        self.lastWeeklySummaryDate = lastWeeklySummaryDate
        self.updatedAt = updatedAt
    }
}

@Model public final class JournalRecord {
    @Attribute(.unique) public var id: UUID
    public var kind: String
    public var date: Date
    public var title: String
    public var body: String
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        kind: String,
        date: Date,
        title: String,
        body: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.kind = kind
        self.date = date
        self.title = title
        self.body = body
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

@Model public final class CalendarEventSnapshotRecord {
    @Attribute(.unique) public var id: UUID
    public var eventIdentifier: String
    public var externalIdentifier: String?
    public var title: String
    public var notes: String
    public var startDate: Date
    public var endDate: Date
    public var calendarTitle: String
    public var isAllDay: Bool
    public var lastSeenAt: Date

    public init(
        id: UUID = UUID(),
        eventIdentifier: String,
        externalIdentifier: String? = nil,
        title: String,
        notes: String = "",
        startDate: Date,
        endDate: Date,
        calendarTitle: String,
        isAllDay: Bool,
        lastSeenAt: Date = Date()
    ) {
        self.id = id
        self.eventIdentifier = eventIdentifier
        self.externalIdentifier = externalIdentifier
        self.title = title
        self.notes = notes
        self.startDate = startDate
        self.endDate = endDate
        self.calendarTitle = calendarTitle
        self.isAllDay = isAllDay
        self.lastSeenAt = lastSeenAt
    }
}

@Model public final class HealthDailySummaryRecord {
    @Attribute(.unique) public var id: UUID
    public var date: Date
    public var stepCount: Double
    public var activeEnergyKilocalories: Double
    public var exerciseMinutes: Double
    public var sleepMinutes: Double
    public var sleepInBedMinutes: Double
    public var sourceDescription: String
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        date: Date,
        stepCount: Double = 0,
        activeEnergyKilocalories: Double = 0,
        exerciseMinutes: Double = 0,
        sleepMinutes: Double = 0,
        sleepInBedMinutes: Double = 0,
        sourceDescription: String = "",
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.date = date
        self.stepCount = stepCount
        self.activeEnergyKilocalories = activeEnergyKilocalories
        self.exerciseMinutes = exerciseMinutes
        self.sleepMinutes = sleepMinutes
        self.sleepInBedMinutes = sleepInBedMinutes
        self.sourceDescription = sourceDescription
        self.updatedAt = updatedAt
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
            JournalSettingsRecord.self,
            JournalRecord.self,
            CalendarEventSnapshotRecord.self,
            HealthDailySummaryRecord.self,
            ToolAuditRecord.self,
            ProviderProfileRecord.self,
        ]
    }
}
