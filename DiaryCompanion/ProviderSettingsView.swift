import DiaryCompanionCore
import SwiftData
import SwiftUI

struct ProviderSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ProviderProfileRecord.displayName)
    private var profiles: [ProviderProfileRecord]
    @State private var isAddingProfile = false
    @State private var errorMessage: String?

    var body: some View {
        List {
            Section("AI Provider") {
                if profiles.isEmpty {
                    Text("尚未配置")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(profiles) { profile in
                        ProviderProfileRow(profile: profile)
                    }
                    .onDelete(perform: deleteProfiles)
                }
            }

            Section("权限") {
                LabeledContent("默认策略", value: "执行前确认")
            }
        }
        .navigationTitle("设置")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("新增 Provider", systemImage: "plus") {
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
            "操作失败",
            isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )
        ) {
            Button("好", role: .cancel) {}
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
    @State private var selectedPreset = ProviderPreset.openAI
    @State private var displayName = ProviderPreset.openAI.displayName
    @State private var baseURL = ProviderPreset.openAI.defaultBaseURL?.absoluteString ?? ""
    @State private var modelName = ""
    @State private var apiKey = ""
    @State private var isEnabled = true
    @State private var validationMessage: String?

    let onSave: (ProviderProfile, String) throws -> Void

    var body: some View {
        Form {
            Section("Provider") {
                Picker("平台", selection: $selectedPreset) {
                    ForEach(ProviderPreset.allCases) { preset in
                        Text(preset.displayName).tag(preset)
                    }
                }
                TextField("显示名称", text: $displayName)
                TextField("Base URL", text: $baseURL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                TextField("模型名称", text: $modelName)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                SecureField("API Key", text: $apiKey)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Toggle("启用", isOn: $isEnabled)
            }

            if let validationMessage {
                Section {
                    Text(validationMessage)
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("新增 Provider")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("取消") {
                    dismiss()
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("保存", action: save)
            }
        }
        .onChange(of: selectedPreset) { _, preset in
            displayName = preset.displayName
            baseURL = preset.defaultBaseURL?.absoluteString ?? ""
        }
    }

    private func save() {
        do {
            let name = try required(displayName, field: "显示名称")
            let urlString = try required(baseURL, field: "Base URL")
            let url = try validBaseURL(urlString)
            let model = try required(modelName, field: "模型名称")
            let key = try required(apiKey, field: "API Key")
            let profile = ProviderProfile(
                displayName: name,
                preset: selectedPreset,
                baseURL: url,
                modelName: model,
                isEnabled: isEnabled
            )
            try onSave(profile, key)
            dismiss()
        } catch {
            validationMessage = error.localizedDescription
        }
    }

    private func required(_ value: String, field: String) throws -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw ProviderSettingsError.required(field)
        }
        return trimmed
    }

    private func validBaseURL(_ value: String) throws -> URL {
        guard let url = URL(string: value),
              let scheme = url.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              url.host != nil
        else {
            throw ProviderSettingsError.invalidBaseURL
        }
        return url
    }
}

private enum ProviderSettingsError: LocalizedError {
    case required(String)
    case invalidBaseURL

    var errorDescription: String? {
        switch self {
        case let .required(field):
            "\(field)不能为空。"
        case .invalidBaseURL:
            "请输入有效的 HTTP 或 HTTPS Base URL。"
        }
    }
}

#Preview {
    NavigationStack {
        ProviderSettingsView()
    }
    .modelContainer(for: DiarySchema.models, inMemory: true)
}
