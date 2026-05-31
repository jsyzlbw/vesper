import Foundation
import Testing
@testable import DiaryCompanionCore

@Test func storesLoadsAndDeletesSecret() throws {
    let service = "DiaryCompanionCoreTests.\(UUID().uuidString)"
    let store = KeychainStore(service: service)
    defer { try? store.delete(account: "openai") }

    try store.save("test-secret", account: "openai")
    #expect(try store.load(account: "openai") == "test-secret")

    try store.delete(account: "openai")
    #expect(try store.load(account: "openai") == nil)
}
