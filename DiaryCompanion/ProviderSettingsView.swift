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
    @State private var connectionMessage: String?
    @State private var isTestingConnection = false

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
                TextField("Base URL（基础地址）", text: $baseURL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                LabeledContent("实际 Endpoint") {
                    Text(endpointPreview)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.trailing)
                }
                TextField("模型名称", text: $modelName)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                SecureField("API Key", text: $apiKey)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Toggle("启用", isOn: $isEnabled)
            }

            Section {
                Button(action: testConnection) {
                    HStack {
                        Text("测试连接")
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
                Text("Base URL 是服务基础地址。应用会自动追加平台对应路径，例如 DeepSeek 会请求 /chat/completions。")
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
                        connectionMessage = "连接成功：\(result.preview)"
                        isTestingConnection = false
                    }
                } catch {
                    await MainActor.run {
                        connectionMessage = "连接失败：\(error.localizedDescription)"
                        isTestingConnection = false
                    }
                }
            }
        } catch {
            validationMessage = error.localizedDescription
        }
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
            return "请先填写有效配置"
        }
    }

    private func makeProfile(
        requireAPIKey: Bool = true,
        requireModel: Bool = true
    ) throws -> ProviderProfile {
        let name = try required(displayName, field: "显示名称")
        let urlString = try required(baseURL, field: "Base URL")
        let url = try validBaseURL(urlString)
        let model = requireModel
            ? try required(modelName, field: "模型名称")
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
