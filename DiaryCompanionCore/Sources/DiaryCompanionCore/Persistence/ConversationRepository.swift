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

    public func fetchConversations() throws -> [ConversationRecord] {
        var descriptor = FetchDescriptor<ConversationRecord>()
        descriptor.sortBy = [SortDescriptor(\.createdAt)]
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
