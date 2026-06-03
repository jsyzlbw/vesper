import DiaryCompanionCore
import SwiftData
import SwiftUI

struct ProviderSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.vesperLocalization) private var localization
    @Query(sort: \ProviderProfileRecord.displayName)
    private var profiles: [ProviderProfileRecord]
    @State private var profileForm: ProviderProfileFormPresentation?
    @State private var debugLogDocument = DebugLogDocument()
    @State private var isExportingDebugLog = false
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
                        Button {
                            editProfile(profile)
                        } label: {
                            ProviderProfileRow(profile: profile)
                        }
                        .buttonStyle(.plain)
                    }
                    .onDelete(perform: deleteProfiles)
                }

                Button {
                    profileForm = .add
                } label: {
                    Label(localization.strings.addProvider, systemImage: "plus.circle.fill")
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
                Button {
                    exportDebugLog()
                } label: {
                    Label(localization.strings.exportDebugLog, systemImage: "square.and.arrow.up")
                }
            }
        }
        .navigationTitle(localization.strings.settings)
        .sheet(item: $profileForm) { presentation in
            NavigationStack {
                ProviderProfileFormView(
                    initialProfile: initialProfile(for: presentation),
                    initialAPIKey: initialAPIKey(for: presentation),
                    isEditing: presentation.isEditing
                ) { profile, apiKey in
                    try ProviderProfileRepository(context: modelContext)
                        .save(profile: profile, apiKey: apiKey)
                }
            }
        }
        .fileExporter(
            isPresented: $isExportingDebugLog,
            document: debugLogDocument,
            contentType: .json,
            defaultFilename: "vesper-debug-log-\(Self.debugLogTimestamp()).json"
        ) { result in
            if case let .failure(error) = result {
                errorMessage = error.localizedDescription
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

    private func editProfile(_ record: ProviderProfileRecord) {
        profileForm = .edit(record.id)
    }

    private func exportDebugLog() {
        do {
            debugLogDocument = try VesperDebugLogExporter(context: modelContext)
                .makeDocument()
            isExportingDebugLog = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func initialProfile(
        for presentation: ProviderProfileFormPresentation
    ) -> ProviderProfile? {
        guard case let .edit(id) = presentation,
              let record = profiles.first(where: { $0.id == id }),
              let preset = ProviderPreset.allCases.first(where: { $0.id == record.presetID }),
              let baseURL = URL(string: record.baseURL)
        else {
            return nil
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

    private func initialAPIKey(
        for presentation: ProviderProfileFormPresentation
    ) -> String? {
        guard case let .edit(id) = presentation else {
            return nil
        }
        return try? ProviderProfileRepository(context: modelContext)
            .loadAPIKey(profileID: id)
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

    private static func debugLogTimestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter.string(from: Date())
    }
}

private enum ProviderProfileFormPresentation: Identifiable {
    case add
    case edit(UUID)

    var id: String {
        switch self {
        case .add:
            "add"
        case let .edit(id):
            "edit-\(id.uuidString)"
        }
    }

    var isEditing: Bool {
        if case .edit = self {
            return true
        }
        return false
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
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .contentShape(Rectangle())
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

    let existingProfileID: UUID?
    let isEditing: Bool
    let onSave: (ProviderProfile, String) throws -> Void

    init(
        initialProfile: ProviderProfile? = nil,
        initialAPIKey: String? = nil,
        isEditing: Bool = false,
        onSave: @escaping (ProviderProfile, String) throws -> Void
    ) {
        let profile = initialProfile
        _selectedPreset = State(initialValue: profile?.preset ?? .openAI)
        _displayName = State(initialValue: profile?.displayName ?? ProviderPreset.openAI.displayName)
        _baseURL = State(initialValue: profile?.baseURL.absoluteString ?? ProviderPreset.openAI.defaultBaseURL?.absoluteString ?? "")
        _modelName = State(initialValue: profile?.modelName ?? "")
        _apiKey = State(initialValue: initialAPIKey ?? "")
        _isEnabled = State(initialValue: profile?.isEnabled ?? true)
        existingProfileID = profile?.id
        self.isEditing = isEditing
        self.onSave = onSave
    }

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
        .navigationTitle(isEditing ? localization.strings.editProvider : localization.strings.addProvider)
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
            let key = try resolvedAPIKey()
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
            let key = try resolvedAPIKey()
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
            id: existingProfileID ?? UUID(),
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

    private func resolvedAPIKey() throws -> String {
        try required(apiKey, field: "API Key")
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
