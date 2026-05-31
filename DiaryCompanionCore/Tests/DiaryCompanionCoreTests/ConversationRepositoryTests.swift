import Foundation
import Testing
@testable import DiaryCompanionCore

@MainActor
@Test func repositoryReusesDefaultConversationAndAppendsStreamedText() throws {
    let container = try DiaryModelContainerFactory.make(inMemory: true)
    let repository = ConversationRepository(context: container.mainContext)

    let first = try repository.defaultConversation()
    let second = try repository.defaultConversation()
    let user = try repository.createMessage(
        conversationID: first.id,
        role: .user,
        content: "你好",
        createdAt: Date(timeIntervalSince1970: 1)
    )
    let assistant = try repository.createMessage(
        conversationID: first.id,
        role: .assistant,
        content: "",
        createdAt: Date(timeIntervalSince1970: 2)
    )

    try repository.appendContent("你", to: assistant.id)
    try repository.appendContent("好", to: assistant.id)

    #expect(first.id == second.id)
    #expect(try repository.fetchConversations().count == 1)
    #expect(try repository.fetchMessages(conversationID: first.id).map(\.id) == [
        user.id,
        assistant.id,
    ])
    #expect(try repository.fetchMessages(conversationID: first.id).last?.content == "你好")
}
