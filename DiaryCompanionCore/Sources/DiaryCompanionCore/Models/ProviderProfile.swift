import Foundation

public enum ProviderProtocolKind: String, Codable, CaseIterable, Sendable {
    case openAI
    case anthropic
    case gemini
    case openAICompatible
}

public enum ProviderPreset: String, Codable, CaseIterable, Identifiable, Sendable {
    case openAI
    case anthropic
    case gemini
    case deepSeek
    case siliconFlow
    case custom

    public var id: String {
        switch self {
        case .openAI: "openai"
        case .anthropic: "anthropic"
        case .gemini: "gemini"
        case .deepSeek: "deepseek"
        case .siliconFlow: "siliconflow"
        case .custom: "custom"
        }
    }

    public var displayName: String {
        switch self {
        case .openAI: "OpenAI"
        case .anthropic: "Anthropic"
        case .gemini: "Gemini"
        case .deepSeek: "DeepSeek"
        case .siliconFlow: "硅基流动"
        case .custom: "Custom"
        }
    }

    public var protocolKind: ProviderProtocolKind {
        switch self {
        case .openAI: .openAI
        case .anthropic: .anthropic
        case .gemini: .gemini
        case .deepSeek, .siliconFlow, .custom: .openAICompatible
        }
    }

    public var defaultBaseURL: URL? {
        switch self {
        case .openAI: URL(string: "https://api.openai.com/v1")
        case .anthropic: URL(string: "https://api.anthropic.com/v1")
        case .gemini: URL(string: "https://generativelanguage.googleapis.com/v1beta")
        case .deepSeek: URL(string: "https://api.deepseek.com")
        case .siliconFlow: URL(string: "https://api.siliconflow.cn/v1")
        case .custom: nil
        }
    }
}

public struct ProviderProfile: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public var displayName: String
    public var preset: ProviderPreset
    public var baseURL: URL
    public var modelName: String
    public var isEnabled: Bool

    public var protocolKind: ProviderProtocolKind {
        preset.protocolKind
    }

    public init(
        id: UUID = UUID(),
        displayName: String,
        preset: ProviderPreset,
        baseURL: URL,
        modelName: String,
        isEnabled: Bool
    ) {
        self.id = id
        self.displayName = displayName
        self.preset = preset
        self.baseURL = baseURL
        self.modelName = modelName
        self.isEnabled = isEnabled
    }
}
