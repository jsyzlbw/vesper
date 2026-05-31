import Foundation
import Testing
@testable import DiaryCompanionCore

@MainActor
@Test func repositoryPersistsProviderMetadataAndRotatesKeychainSecret() throws {
    let container = try DiaryModelContainerFactory.make(inMemory: true)
    let keychain = KeychainStore(service: "ProviderProfileRepositoryTests.\(UUID().uuidString)")
    let repository = ProviderProfileRepository(
        context: container.mainContext,
        keychainStore: keychain
    )
    var profile = ProviderProfile(
        displayName: "Campus Proxy",
        preset: .custom,
        baseURL: try #require(URL(string: "https://example.com/v1")),
        modelName: "campus-model",
        isEnabled: true
    )
    defer { try? repository.delete(profileID: profile.id) }

    try repository.save(profile: profile, apiKey: "first-secret")

    #expect(try repository.fetchProfiles() == [profile])
    #expect(try repository.loadAPIKey(profileID: profile.id) == "first-secret")

    profile.displayName = "Campus Proxy Updated"
    profile.modelName = "campus-model-v2"
    try repository.save(profile: profile, apiKey: "rotated-secret")

    #expect(try repository.fetchProfiles() == [profile])
    #expect(try repository.loadAPIKey(profileID: profile.id) == "rotated-secret")

    try repository.delete(profileID: profile.id)

    #expect(try repository.fetchProfiles().isEmpty)
    #expect(try repository.loadAPIKey(profileID: profile.id) == nil)
}
