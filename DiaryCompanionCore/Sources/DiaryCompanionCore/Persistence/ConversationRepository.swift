import Foundation
import SwiftData

@MainActor
public final class ConversationRepository {
    public static let defaultConversationID = UUID(
        uuidString: "00000000-0000-0000-0000-000000000001"
    )!

    private let context: ModelContext

    public init(context: ModelContext) {
        self.context = context
    }

    public func defaultConversation() throws -> ConversationRecord {
        if let existing = try findConversation(id: Self.defaultConversationID) {
            return existing
        }

        let conversation = ConversationRecord(
            id: Self.defaultConversationID,
            title: "默认对话"
        )
        context.insert(conversation)
        try context.save()
        return conversation
    }

    public func dailyConversation(
        now: Date = Date(),
        rolloverHour: Int = 4,
        calendar: Calendar = .current
    ) throws -> ConversationRecord {
        let day = Self.logicalDay(
            for: now,
            rolloverHour: rolloverHour,
            calendar: calendar
        )
        if let existing = try findConversation(logicalDay: day) {
            return existing
        }

        let conversation = ConversationRecord(
            title: Self.dailyTitle(for: day),
            logicalDay: day,
            createdAt: now,
            updatedAt: now
        )
        context.insert(conversation)
        try context.save()
        return conversation
    }

    public nonisolated static func logicalDay(
        for date: Date,
        rolloverHour: Int = 4,
        calendar: Calendar = .current
    ) -> Date {
        let safeHour = min(max(rolloverHour, 0), 23)
        let hour = calendar.component(.hour, from: date)
        let effectiveDate = hour < safeHour
            ? calendar.date(byAdding: .day, value: -1, to: date) ?? date
            : date
        return calendar.startOfDay(for: effectiveDate)
    }

    public nonisolated static func dailyTitle(for logicalDay: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = .current
        formatter.locale = Locale(identifier: "zh_Hans_CN")
        formatter.dateFormat = "yyyy年M月d日"
        return formatter.string(from: logicalDay)
    }

    @discardableResult
    public func createMessage(
        conversationID: UUID,
        role: ChatRole,
        content: String,
        createdAt: Date = Date()
    ) throws -> MessageRecord {
        let message = MessageRecord(
            conversationID: conversationID,
            role: role.rawValue,
            content: content,
            createdAt: createdAt
        )
        context.insert(message)
        try context.save()
        return message
    }

    public func appendContent(_ delta: String, to messageID: UUID) throws {
        guard let message = try findMessage(id: messageID) else {
            throw ConversationRepositoryError.messageNotFound(messageID)
        }
        message.content.append(delta)
        try context.save()
    }

    public func replaceContent(_ content: String, of messageID: UUID) throws {
        guard let message = try findMessage(id: messageID) else {
            throw ConversationRepositoryError.messageNotFound(messageID)
        }
        message.content = content
        try context.save()
    }

    public func fetchConversations() throws -> [ConversationRecord] {
        var descriptor = FetchDescriptor<ConversationRecord>()
        descriptor.sortBy = [SortDescriptor(\.createdAt, order: .reverse)]
        return try context.fetch(descriptor)
    }

    public func fetchMessages(conversationID: UUID) throws -> [MessageRecord] {
        var descriptor = FetchDescriptor<MessageRecord>(
            predicate: #Predicate { $0.conversationID == conversationID }
        )
        descriptor.sortBy = [SortDescriptor(\.createdAt)]
        return try context.fetch(descriptor)
    }

    private func findConversation(id: UUID) throws -> ConversationRecord? {
        let descriptor = FetchDescriptor<ConversationRecord>(
            predicate: #Predicate { $0.id == id }
        )
        return try context.fetch(descriptor).first
    }

    private func findConversation(logicalDay: Date) throws -> ConversationRecord? {
        let descriptor = FetchDescriptor<ConversationRecord>(
            predicate: #Predicate { $0.logicalDay == logicalDay }
        )
        return try context.fetch(descriptor).first
    }

    private func findMessage(id: UUID) throws -> MessageRecord? {
        let descriptor = FetchDescriptor<MessageRecord>(
            predicate: #Predicate { $0.id == id }
        )
        return try context.fetch(descriptor).first
    }
}

public enum ConversationRepositoryError: Error, Equatable {
    case messageNotFound(UUID)
}
