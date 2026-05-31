import Foundation
import Testing
@testable import DiaryCompanionCore

@Test func buildsOpenAIStreamingChatCompletionsRequest() throws {
    let request = try ProviderRequestFactory().makeStreamingRequest(
        profile: try profile(.openAI, modelName: "gpt-5-mini"),
        apiKey: "openai-secret",
        messages: [.init(role: .user, content: "记录今天跑了三公里")]
    )
    let body = try jsonBody(request)

    #expect(request.url?.absoluteString == "https://api.openai.com/v1/chat/completions")
    #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer openai-secret")
    #expect(request.value(forHTTPHeaderField: "Accept") == "text/event-stream")
    #expect(body["model"] as? String == "gpt-5-mini")
    #expect(body["stream"] as? Bool == true)
    #expect(message(at: 0, in: body)["role"] as? String == "user")
    #expect(message(at: 0, in: body)["content"] as? String == "记录今天跑了三公里")
}

@Test func buildsOpenAICompatibleRequestsForRequiredProfiles() throws {
    let factory = ProviderRequestFactory()
    let messages = [ChatMessage(role: .user, content: "你好")]

    let deepSeek = try factory.makeStreamingRequest(
        profile: try profile(.deepSeek, modelName: "deepseek-chat"),
        apiKey: "deepseek-secret",
        messages: messages
    )
    let siliconFlow = try factory.makeStreamingRequest(
        profile: try profile(.siliconFlow, modelName: "Qwen/Qwen3-8B"),
        apiKey: "siliconflow-secret",
        messages: messages
    )
    let custom = try factory.makeStreamingRequest(
        profile: ProviderProfile(
            displayName: "Campus Proxy",
            preset: .custom,
            baseURL: try #require(URL(string: "https://example.com/proxy/v1")),
            modelName: "campus-model",
            isEnabled: true
        ),
        apiKey: "custom-secret",
        messages: messages
    )

    #expect(deepSeek.url?.absoluteString == "https://api.deepseek.com/chat/completions")
    #expect(siliconFlow.url?.absoluteString == "https://api.siliconflow.com/v1/chat/completions")
    #expect(custom.url?.absoluteString == "https://example.com/proxy/v1/chat/completions")
}

@Test func resolvesDeepSeekBaseURLToChatCompletionsEndpoint() throws {
    let endpoint = try ProviderRequestFactory().endpointURL(
        for: try profile(.deepSeek, modelName: "deepseek-v4-flash")
    )

    #expect(ProviderPreset.deepSeek.defaultBaseURL?.absoluteString == "https://api.deepseek.com")
    #expect(endpoint.absoluteString == "https://api.deepseek.com/chat/completions")
}

@Test func buildsAnthropicMessagesRequest() throws {
    let request = try ProviderRequestFactory().makeStreamingRequest(
        profile: try profile(.anthropic, modelName: "claude-sonnet-4-20250514"),
        apiKey: "anthropic-secret",
        messages: [
            .init(role: .system, content: "你是日记助手"),
            .init(role: .user, content: "记录午饭"),
            .init(role: .assistant, content: "好的"),
        ],
        maxOutputTokens: 768
    )
    let body = try jsonBody(request)

    #expect(request.url?.absoluteString == "https://api.anthropic.com/v1/messages")
    #expect(request.value(forHTTPHeaderField: "x-api-key") == "anthropic-secret")
    #expect(request.value(forHTTPHeaderField: "anthropic-version") == "2023-06-01")
    #expect(body["model"] as? String == "claude-sonnet-4-20250514")
    #expect(body["max_tokens"] as? Int == 768)
    #expect(body["stream"] as? Bool == true)
    #expect(body["system"] as? String == "你是日记助手")
    #expect(messages(in: body).count == 2)
    #expect(message(at: 0, in: body)["role"] as? String == "user")
    #expect(message(at: 1, in: body)["role"] as? String == "assistant")
}

@Test func buildsGeminiStreamingGenerateContentRequest() throws {
    let request = try ProviderRequestFactory().makeStreamingRequest(
        profile: try profile(.gemini, modelName: "gemini-2.5-flash"),
        apiKey: "gemini-secret",
        messages: [
            .init(role: .system, content: "你是日记助手"),
            .init(role: .user, content: "记录午饭"),
            .init(role: .assistant, content: "好的"),
        ]
    )
    let body = try jsonBody(request)
    let contents = try #require(body["contents"] as? [[String: Any]])
    let systemInstruction = try #require(body["systemInstruction"] as? [String: Any])

    #expect(request.url?.absoluteString == "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:streamGenerateContent?alt=sse")
    #expect(request.value(forHTTPHeaderField: "x-goog-api-key") == "gemini-secret")
    #expect(contents.count == 2)
    #expect(contents[0]["role"] as? String == "user")
    #expect(contents[1]["role"] as? String == "model")
    #expect(text(in: systemInstruction) == "你是日记助手")
    #expect(text(in: contents[0]) == "记录午饭")
}

private func profile(
    _ preset: ProviderPreset,
    modelName: String
) throws -> ProviderProfile {
    ProviderProfile(
        displayName: preset.displayName,
        preset: preset,
        baseURL: try #require(preset.defaultBaseURL),
        modelName: modelName,
        isEnabled: true
    )
}

private func jsonBody(_ request: URLRequest) throws -> [String: Any] {
    let data = try #require(request.httpBody)
    return try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
}

private func messages(in body: [String: Any]) -> [[String: Any]] {
    body["messages"] as? [[String: Any]] ?? []
}

private func message(at index: Int, in body: [String: Any]) -> [String: Any] {
    messages(in: body)[index]
}

private func text(in content: [String: Any]) -> String? {
    let parts = content["parts"] as? [[String: Any]]
    return parts?.first?["text"] as? String
}
