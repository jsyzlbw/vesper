import Foundation

public enum ChatRole: String, Codable, Sendable {
    case system
    case user
    case assistant
}

public struct ChatMessage: Codable, Equatable, Sendable {
    public var role: ChatRole
    public var content: String

    public init(role: ChatRole, content: String) {
        self.role = role
        self.content = content
    }
}

public struct ProviderRequestFactory: Sendable {
    public init() {}

    public func endpointURL(for profile: ProviderProfile) throws -> URL {
        switch profile.protocolKind {
        case .openAI, .openAICompatible:
            profile.baseURL
                .appendingPathComponent("chat")
                .appendingPathComponent("completions")
        case .anthropic:
            profile.baseURL.appendingPathComponent("messages")
        case .gemini:
            try geminiEndpointURL(profile: profile)
        }
    }

    public func makeStreamingRequest(
        profile: ProviderProfile,
        apiKey: String,
        messages: [ChatMessage],
        maxOutputTokens: Int = 1_024
    ) throws -> URLRequest {
        switch profile.protocolKind {
        case .openAI, .openAICompatible:
            try makeOpenAICompatibleRequest(
                profile: profile,
                apiKey: apiKey,
                messages: messages
            )
        case .anthropic:
            try makeAnthropicRequest(
                profile: profile,
                apiKey: apiKey,
                messages: messages,
                maxOutputTokens: maxOutputTokens
            )
        case .gemini:
            try makeGeminiRequest(
                profile: profile,
                apiKey: apiKey,
                messages: messages
            )
        }
    }

    private func makeOpenAICompatibleRequest(
        profile: ProviderProfile,
        apiKey: String,
        messages: [ChatMessage]
    ) throws -> URLRequest {
        var request = makeJSONRequest(
            url: try endpointURL(for: profile)
        )
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try encode(
            OpenAICompatiblePayload(
                model: profile.modelName,
                messages: messages,
                stream: true
            )
        )
        return request
    }

    private func makeAnthropicRequest(
        profile: ProviderProfile,
        apiKey: String,
        messages: [ChatMessage],
        maxOutputTokens: Int
    ) throws -> URLRequest {
        var request = makeJSONRequest(
            url: try endpointURL(for: profile)
        )
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.httpBody = try encode(
            AnthropicPayload(
                model: profile.modelName,
                maxTokens: maxOutputTokens,
                messages: messages.filter { $0.role != .system },
                stream: true,
                system: combinedSystemPrompt(from: messages)
            )
        )
        return request
    }

    private func makeGeminiRequest(
        profile: ProviderProfile,
        apiKey: String,
        messages: [ChatMessage]
    ) throws -> URLRequest {
        var request = makeJSONRequest(url: try endpointURL(for: profile))
        request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
        request.httpBody = try encode(
            GeminiPayload(
                contents: messages.compactMap(GeminiContent.init(message:)),
                systemInstruction: combinedSystemPrompt(from: messages).map {
                    GeminiContent(role: nil, parts: [.init(text: $0)])
                }
            )
        )
        return request
    }

    private func makeJSONRequest(url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        return request
    }

    private func combinedSystemPrompt(from messages: [ChatMessage]) -> String? {
        let prompt = messages
            .filter { $0.role == .system }
            .map(\.content)
            .joined(separator: "\n")
        return prompt.isEmpty ? nil : prompt
    }

    private func requiredURL(from components: URLComponents?) throws -> URL {
        guard let url = components?.url else {
            throw ProviderRequestError.invalidURL
        }
        return url
    }

    private func geminiEndpointURL(profile: ProviderProfile) throws -> URL {
        let modelName = profile.modelName.removingPrefix("models/")
        let endpoint = profile.baseURL
            .appendingPathComponent("models")
            .appendingPathComponent("\(modelName):streamGenerateContent")
        var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "alt", value: "sse")]
        return try requiredURL(from: components)
    }

    private func encode(_ payload: some Encodable) throws -> Data {
        try JSONEncoder().encode(payload)
    }
}

public enum ProviderRequestError: Error, Equatable, Sendable {
    case invalidURL
}

private struct OpenAICompatiblePayload: Encodable {
    let model: String
    let messages: [ChatMessage]
    let stream: Bool
}

private struct AnthropicPayload: Encodable {
    let model: String
    let maxTokens: Int
    let messages: [ChatMessage]
    let stream: Bool
    let system: String?

    enum CodingKeys: String, CodingKey {
        case model
        case maxTokens = "max_tokens"
        case messages
        case stream
        case system
    }
}

private struct GeminiPayload: Encodable {
    let contents: [GeminiContent]
    let systemInstruction: GeminiContent?
}

private struct GeminiContent: Encodable {
    let role: String?
    let parts: [GeminiPart]

    init(role: String?, parts: [GeminiPart]) {
        self.role = role
        self.parts = parts
    }

    init?(message: ChatMessage) {
        switch message.role {
        case .system:
            return nil
        case .user:
            role = "user"
        case .assistant:
            role = "model"
        }
        parts = [.init(text: message.content)]
    }
}

private struct GeminiPart: Encodable {
    let text: String
}

private extension String {
    func removingPrefix(_ prefix: String) -> String {
        hasPrefix(prefix) ? String(dropFirst(prefix.count)) : self
    }
}
