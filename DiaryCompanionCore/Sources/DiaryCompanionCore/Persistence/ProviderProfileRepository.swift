import Foundation
import SwiftData

@MainActor
public final class ProviderProfileRepository {
    private let context: ModelContext
    private let keychainStore: KeychainStore

    public init(
        context: ModelContext,
        keychainStore: KeychainStore = KeychainStore()
    ) {
        self.context = context
        self.keychainStore = keychainStore
    }

    public func save(profile: ProviderProfile, apiKey: String) throws {
        try keychainStore.save(apiKey, account: keychainAccount(for: profile.id))

        let record = try findRecord(profileID: profile.id) ?? ProviderProfileRecord(
            id: profile.id,
            displayName: profile.displayName,
            presetID: profile.preset.id,
            baseURL: profile.baseURL.absoluteString,
            modelName: profile.modelName,
            isEnabled: profile.isEnabled
        )
        record.displayName = profile.displayName
        record.presetID = profile.preset.id
        record.baseURL = profile.baseURL.absoluteString
        record.modelName = profile.modelName
        record.isEnabled = profile.isEnabled

        if record.modelContext == nil {
            context.insert(record)
        }
        try context.save()
    }

    public func fetchProfiles() throws -> [ProviderProfile] {
        var descriptor = FetchDescriptor<ProviderProfileRecord>()
        descriptor.sortBy = [SortDescriptor(\.displayName)]
        return try context.fetch(descriptor).map(makeProfile(record:))
    }

    public func loadAPIKey(profileID: UUID) throws -> String? {
        try keychainStore.load(account: keychainAccount(for: profileID))
    }

    public func delete(profileID: UUID) throws {
        try keychainStore.delete(account: keychainAccount(for: profileID))
        if let record = try findRecord(profileID: profileID) {
            context.delete(record)
            try context.save()
        }
    }

    private func findRecord(profileID: UUID) throws -> ProviderProfileRecord? {
        let descriptor = FetchDescriptor<ProviderProfileRecord>(
            predicate: #Predicate { $0.id == profileID }
        )
        return try context.fetch(descriptor).first
    }

    private func makeProfile(record: ProviderProfileRecord) throws -> ProviderProfile {
        guard let preset = ProviderPreset.allCases.first(where: { $0.id == record.presetID }) else {
            throw ProviderProfileRepositoryError.invalidPresetID(record.presetID)
        }
        guard let baseURL = URL(string: record.baseURL) else {
            throw ProviderProfileRepositoryError.invalidBaseURL(record.baseURL)
        }
        return ProviderProfile(
            id: record.id,
            displayName: record.displayName,
            preset: preset,
            baseURL: baseURL,
            modelName: record.modelName,
            isEnabled: record.isEnabled
        )
    }

    private func keychainAccount(for profileID: UUID) -> String {
        "provider-api-key:\(profileID.uuidString)"
    }
}

public enum ProviderProfileRepositoryError: Error, Equatable {
    case invalidPresetID(String)
    case invalidBaseURL(String)
}
