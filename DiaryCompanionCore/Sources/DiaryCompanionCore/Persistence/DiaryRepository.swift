import Foundation
import SwiftData

public enum DiaryRepositoryError: Error, Equatable, Sendable {
    case reminderNotFound(UUID)
    case invalidReminderSchedulingMode(String)
    case invalidReminderStatus(String)
    case invalidReminderExecutionResult(String)
    case invalidReminderRecurrenceData
    case invalidReminderSearchWindow
    case reminderRequiresExecutionReset(UUID)
    case legacyRepeatingReminderRequiresReconfirmation(UUID)
}

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

    @discardableResult
    public func createReminderProposal(
        _ proposal: ReminderProposal,
        sourceMessageID: UUID?
    ) throws -> ReminderRecord {
        try proposal.validate()
        let record = ReminderRecord(
            title: proposal.title,
            notes: proposal.notes,
            firstOccurrence: proposal.start,
            durationMinutes: proposal.durationMinutes,
            recurrenceData: try JSONEncoder().encode(proposal.recurrence),
            schedulingMode: proposal.schedulingMode.rawValue,
            searchWindowStart: proposal.searchWindow?.start,
            searchWindowEnd: proposal.searchWindow?.end,
            notificationEnabled: proposal.notificationEnabled,
            calendarEnabled: proposal.calendarEnabled,
            sourceMessageID: sourceMessageID
        )
        record.repeats = proposal.recurrence.isRepeating
        context.insert(record)
        try context.save()
        return record
    }

    public func fetchReminders() throws -> [ReminderRecord] {
        var descriptor = FetchDescriptor<ReminderRecord>()
        descriptor.sortBy = [SortDescriptor(\.fireDate)]
        return try context.fetch(descriptor)
    }

    public func fetchReminders(sourceMessageID: UUID) throws -> [ReminderRecord] {
        var descriptor = FetchDescriptor<ReminderRecord>(
            predicate: #Predicate { $0.sourceMessageID == sourceMessageID }
        )
        descriptor.sortBy = [SortDescriptor(\.fireDate)]
        return try context.fetch(descriptor)
    }

    public func reminderProposal(from record: ReminderRecord) throws -> ReminderProposal {
        if record.hasMigratedLegacyDefaults {
            guard !record.repeats else {
                throw DiaryRepositoryError
                    .legacyRepeatingReminderRequiresReconfirmation(record.id)
            }
            return try reconstructMigratedLegacyReminder(from: record)
        }
        guard ReminderProposalStatus(rawValue: record.status) != nil else {
            throw DiaryRepositoryError.invalidReminderStatus(record.status)
        }
        try validateExecutionResult(record.notificationResult)
        try validateExecutionResult(record.calendarResult)
        guard let schedulingMode = ReminderSchedulingMode(rawValue: record.schedulingMode) else {
            throw DiaryRepositoryError.invalidReminderSchedulingMode(record.schedulingMode)
        }
        let recurrence: ReminderRecurrenceRule
        do {
            recurrence = try JSONDecoder().decode(
                ReminderRecurrenceRule.self,
                from: record.recurrenceData
            )
        } catch {
            throw DiaryRepositoryError.invalidReminderRecurrenceData
        }
        let searchWindow: ReminderSearchWindow?
        switch (record.searchWindowStart, record.searchWindowEnd) {
        case let (start?, end?):
            searchWindow = ReminderSearchWindow(start: start, end: end)
        case (nil, nil):
            searchWindow = nil
        default:
            throw DiaryRepositoryError.invalidReminderSearchWindow
        }
        let proposal = ReminderProposal(
            title: record.title,
            notes: record.notes,
            start: record.firstOccurrence,
            durationMinutes: record.durationMinutes,
            recurrence: recurrence,
            schedulingMode: schedulingMode,
            searchWindow: searchWindow,
            notificationEnabled: record.notificationEnabled,
            calendarEnabled: record.calendarEnabled
        )
        try proposal.validate()
        return proposal
    }

    public func updateReminderExecution(
        id: UUID,
        status: ReminderProposalStatus,
        notificationResult: ReminderExecutionResult,
        calendarResult: ReminderExecutionResult,
        notificationIdentifiers: [String],
        calendarEventIdentifier: String?,
        calendarExternalIdentifier: String?
    ) throws {
        let record = try reminder(id: id)
        record.status = status.rawValue
        record.notificationResult = notificationResult.rawValue
        record.calendarResult = calendarResult.rawValue
        record.notificationIdentifiers = notificationIdentifiers.stableUniqued()
        record.calendarEventIdentifier = calendarEventIdentifier
        record.calendarExternalIdentifier = calendarExternalIdentifier
        record.isScheduled = status == .scheduled
        try context.save()
    }

    func resetReminderExecution(id: UUID) throws {
        let record = try reminder(id: id)
        record.status = ReminderProposalStatus.pendingConfirmation.rawValue
        record.notificationResult = ReminderExecutionResult.notRequested.rawValue
        record.calendarResult = ReminderExecutionResult.notRequested.rawValue
        record.notificationIdentifiers = []
        record.calendarEventIdentifier = nil
        record.calendarExternalIdentifier = nil
        record.isScheduled = false
        try context.save()
    }

    public func updateReminderProposal(
        id: UUID,
        proposal: ReminderProposal
    ) throws {
        try proposal.validate()
        let record = try reminder(id: id)
        guard !record.requiresExecutionResetForEditing else {
            throw DiaryRepositoryError.reminderRequiresExecutionReset(id)
        }
        record.title = proposal.title
        record.body = proposal.notes
        record.fireDate = proposal.start ?? proposal.searchWindow?.start ?? .distantPast
        record.repeats = proposal.recurrence.isRepeating
        record.notes = proposal.notes
        record.firstOccurrence = proposal.start
        record.durationMinutes = proposal.durationMinutes
        record.recurrenceData = try JSONEncoder().encode(proposal.recurrence)
        record.schedulingMode = proposal.schedulingMode.rawValue
        record.searchWindowStart = proposal.searchWindow?.start
        record.searchWindowEnd = proposal.searchWindow?.end
        record.notificationEnabled = proposal.notificationEnabled
        record.calendarEnabled = proposal.calendarEnabled
        try context.save()
    }

    public func cancelReminder(id: UUID) throws {
        let record = try reminder(id: id)
        guard record.canCancelDirectly else {
            throw DiaryRepositoryError.reminderRequiresExecutionReset(id)
        }
        record.status = ReminderProposalStatus.cancelled.rawValue
        record.isScheduled = false
        try context.save()
    }

    public func fetchAuditLogs() throws -> [ToolAuditRecord] {
        var descriptor = FetchDescriptor<ToolAuditRecord>()
        descriptor.sortBy = [SortDescriptor(\.createdAt, order: .reverse)]
        return try context.fetch(descriptor)
    }

    func reminder(id: UUID) throws -> ReminderRecord {
        let descriptor = FetchDescriptor<ReminderRecord>(
            predicate: #Predicate { $0.id == id }
        )
        guard let record = try context.fetch(descriptor).first else {
            throw DiaryRepositoryError.reminderNotFound(id)
        }
        return record
    }

    private func validateExecutionResult(_ rawValue: String) throws {
        guard ReminderExecutionResult(rawValue: rawValue) != nil else {
            throw DiaryRepositoryError.invalidReminderExecutionResult(rawValue)
        }
    }

    private func reconstructMigratedLegacyReminder(
        from record: ReminderRecord
    ) throws -> ReminderProposal {
        let recurrence = ReminderRecurrenceRule.once
        let status: ReminderProposalStatus = record.isScheduled
            ? .scheduled
            : .pendingConfirmation
        let notificationResult: ReminderExecutionResult = record.isScheduled
            ? .scheduled
            : .notRequested
        let proposal = ReminderProposal(
            title: record.title,
            notes: record.body,
            start: record.fireDate,
            durationMinutes: 1,
            recurrence: recurrence,
            schedulingMode: .fixed,
            searchWindow: nil,
            notificationEnabled: true,
            calendarEnabled: false
        )
        try proposal.validate()

        record.notes = proposal.notes
        record.firstOccurrence = proposal.start
        record.durationMinutes = proposal.durationMinutes
        record.recurrenceData = try JSONEncoder().encode(recurrence)
        record.notificationEnabled = proposal.notificationEnabled
        record.status = status.rawValue
        record.notificationResult = notificationResult.rawValue
        try context.save()
        return proposal
    }
}

private extension ReminderRecord {
    var hasMigratedLegacyDefaults: Bool {
        recurrenceData.isEmpty
            && notes.isEmpty
            && firstOccurrence == nil
            && durationMinutes == 0
            && schedulingMode == ReminderSchedulingMode.fixed.rawValue
            && searchWindowStart == nil
            && searchWindowEnd == nil
            && notificationEnabled == false
            && calendarEnabled == false
            && status == ReminderProposalStatus.pendingConfirmation.rawValue
            && notificationResult == ReminderExecutionResult.notRequested.rawValue
            && calendarResult == ReminderExecutionResult.notRequested.rawValue
            && sourceMessageID == nil
            && notificationIdentifiers.isEmpty
            && calendarEventIdentifier == nil
            && calendarExternalIdentifier == nil
    }

    var hasExternalResourceIdentifiers: Bool {
        !notificationIdentifiers.isEmpty
            || calendarEventIdentifier != nil
            || calendarExternalIdentifier != nil
    }

    var requiresExecutionResetForEditing: Bool {
        status == ReminderProposalStatus.scheduled.rawValue
            || status == ReminderProposalStatus.executing.rawValue
            || hasExternalResourceIdentifiers
    }

    var canCancelDirectly: Bool {
        status == ReminderProposalStatus.pendingConfirmation.rawValue
            && !hasExternalResourceIdentifiers
    }
}

private extension ReminderRecurrenceRule {
    var isRepeating: Bool {
        if case .once = self {
            return false
        }
        return true
    }
}

private extension [String] {
    func stableUniqued() -> [String] {
        var seen: Set<String> = []
        return filter { seen.insert($0).inserted }
    }
}
