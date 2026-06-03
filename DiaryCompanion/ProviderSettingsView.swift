import DiaryCompanionCore
import SwiftData
import SwiftUI

struct ProviderSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.vesperLocalization) private var localization
    @Query(sort: \ProviderProfileRecord.displayName)
    private var profiles: [ProviderProfileRecord]
    @State private var isAddingProfile = false
    @State private var errorMessage: String?
    @AppStorage("vesper.appLanguage")
    private var appLanguageRawValue = VesperLanguage.followSystem.rawValue

    var body: some View {
        List {
            Section(localization.strings.aiProvider) {
                if profiles.isEmpty {
                    Text(localization.strings.notConfigured)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(profiles) { profile in
                        ProviderProfileRow(profile: profile)
                    }
                    .onDelete(perform: deleteProfiles)
                }
            }

            Section(localization.strings.appLanguage) {
                Picker(localization.strings.appLanguage, selection: $appLanguageRawValue) {
                    ForEach(VesperLanguage.allCases, id: \.rawValue) { language in
                        Text(localization.strings.languageName(language))
                            .tag(language.rawValue)
                    }
                }
                .labelsHidden()
            }

            Section(localization.strings.permissions) {
                LabeledContent(
                    localization.strings.defaultPolicy,
                    value: localization.strings.confirmBeforeExecution
                )
            }

            Section(localization.strings.support) {
                NavigationLink {
                    VesperUserGuideView()
                } label: {
                    Label(localization.strings.userGuide, systemImage: "book.closed")
                }
            }
        }
        .navigationTitle(localization.strings.settings)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(localization.strings.addProvider, systemImage: "plus") {
                    isAddingProfile = true
                }
            }
        }
        .sheet(isPresented: $isAddingProfile) {
            NavigationStack {
                ProviderProfileFormView { profile, apiKey in
                    try ProviderProfileRepository(context: modelContext)
                        .save(profile: profile, apiKey: apiKey)
                }
            }
        }
        .alert(
            localization.strings.operationFailed,
            isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )
        ) {
            Button(localization.strings.ok, role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func deleteProfiles(at offsets: IndexSet) {
        do {
            let repository = ProviderProfileRepository(context: modelContext)
            for index in offsets {
                try repository.delete(profileID: profiles[index].id)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct ProviderProfileRow: View {
    let profile: ProviderProfileRecord

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: profile.isEnabled ? "checkmark.circle.fill" : "pause.circle")
                .foregroundStyle(profile.isEnabled ? .green : .secondary)
            VStack(alignment: .leading, spacing: 3) {
                Text(profile.displayName)
                Text("\(presetDisplayName) · \(profile.modelName)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }

    private var presetDisplayName: String {
        ProviderPreset.allCases
            .first(where: { $0.id == profile.presetID })?
            .displayName ?? profile.presetID
    }
}

private struct ProviderProfileFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.vesperLocalization) private var localization
    @State private var selectedPreset = ProviderPreset.openAI
    @State private var displayName = ProviderPreset.openAI.displayName
    @State private var baseURL = ProviderPreset.openAI.defaultBaseURL?.absoluteString ?? ""
    @State private var modelName = ""
    @State private var apiKey = ""
    @State private var isEnabled = true
    @State private var validationMessage: String?
    @State private var connectionMessage: String?
    @State private var isTestingConnection = false

    let onSave: (ProviderProfile, String) throws -> Void

    var body: some View {
        Form {
            Section(localization.strings.provider) {
                Picker(localization.strings.platform, selection: $selectedPreset) {
                    ForEach(ProviderPreset.allCases) { preset in
                        Text(preset.displayName).tag(preset)
                    }
                }
                TextField(localization.strings.displayName, text: $displayName)
                TextField(localization.strings.baseURL, text: $baseURL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                LabeledContent(localization.strings.actualEndpoint) {
                    Text(endpointPreview)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.trailing)
                }
                TextField(localization.strings.modelName, text: $modelName)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                SecureField("API Key", text: $apiKey)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Toggle(localization.strings.enabled, isOn: $isEnabled)
            }

            Section {
                Button(action: testConnection) {
                    HStack {
                        Text(localization.strings.testConnection)
                        Spacer()
                        if isTestingConnection {
                            ProgressView()
                        }
                    }
                }
                .disabled(isTestingConnection)

                if let connectionMessage {
                    Text(connectionMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } footer: {
                Text(localization.strings.endpointFooter)
            }

            if let validationMessage {
                Section {
                    Text(validationMessage)
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle(localization.strings.addProvider)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(localization.strings.cancel) {
                    dismiss()
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(localization.strings.save, action: save)
            }
        }
        .onChange(of: selectedPreset) { _, preset in
            displayName = preset.displayName
            baseURL = preset.defaultBaseURL?.absoluteString ?? ""
            connectionMessage = nil
        }
    }

    private func save() {
        do {
            let profile = try makeProfile()
            let key = try required(apiKey, field: "API Key")
            try onSave(profile, key)
            dismiss()
        } catch {
            validationMessage = error.localizedDescription
        }
    }

    private func testConnection() {
        guard !isTestingConnection else {
            return
        }
        do {
            let profile = try makeProfile()
            let key = try required(apiKey, field: "API Key")
            validationMessage = nil
            connectionMessage = nil
            isTestingConnection = true

            Task {
                do {
                    let result = try await ProviderConnectionTester().test(
                        profile: profile,
                        apiKey: key
                    )
                    await MainActor.run {
                        connectionMessage = localization.strings.connectionSucceeded(result.preview)
                        isTestingConnection = false
                    }
                } catch {
                    await MainActor.run {
                        connectionMessage = localization.strings.connectionFailed(
                            localizedMessage(for: error)
                        )
                        isTestingConnection = false
                    }
                }
            }
        } catch {
            validationMessage = error.localizedDescription
        }
    }

    private func localizedMessage(for error: Error) -> String {
        if let error = error as? ProviderConnectionTestError {
            return error.localizedDescription(language: localization.language)
        }
        if let error = error as? ProviderStreamError {
            return error.localizedDescription(language: localization.language)
        }
        return error.localizedDescription
    }

    private var endpointPreview: String {
        do {
            return try ProviderRequestFactory()
                .endpointURL(
                    for: makeProfile(
                        requireAPIKey: false,
                        requireModel: false
                    )
                )
                .absoluteString
        } catch {
            return localization.strings.invalidConfiguration
        }
    }

    private func makeProfile(
        requireAPIKey: Bool = true,
        requireModel: Bool = true
    ) throws -> ProviderProfile {
        let name = try required(displayName, field: localization.strings.displayName)
        let urlString = try required(baseURL, field: "Base URL")
        let url = try validBaseURL(urlString)
        let model = requireModel
            ? try required(modelName, field: localization.strings.modelName)
            : modelName.trimmingCharacters(in: .whitespacesAndNewlines)
        if requireAPIKey {
            _ = try required(apiKey, field: "API Key")
        }
        return ProviderProfile(
            displayName: name,
            preset: selectedPreset,
            baseURL: url,
            modelName: model.isEmpty ? "{model}" : model,
            isEnabled: isEnabled
        )
    }

    private func required(_ value: String, field: String) throws -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw ProviderSettingsError.required(
                localization.strings.required(field)
            )
        }
        return trimmed
    }

    private func validBaseURL(_ value: String) throws -> URL {
        guard let url = URL(string: value),
              let scheme = url.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              url.host != nil
        else {
            throw ProviderSettingsError.invalidBaseURL(
                localization.strings.invalidBaseURL
            )
        }
        return url
    }
}

private enum ProviderSettingsError: LocalizedError {
    case required(String)
    case invalidBaseURL(String)

    var errorDescription: String? {
        switch self {
        case let .required(message), let .invalidBaseURL(message):
            message
        }
    }
}

#Preview {
    NavigationStack {
        ProviderSettingsView()
    }
    .modelContainer(for: DiarySchema.models, inMemory: true)
}
