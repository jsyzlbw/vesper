import Foundation
import Testing
@testable import DiaryCompanionCore

@Test func streamingClientYieldsOpenAICompatibleEvents() async throws {
    let client = ProviderStreamingClient(
        lineStreamer: StubEventLineStreamer(
            lines: [
                #"data: {"choices":[{"delta":{"reasoning_content":"分析"}}]}"#,
                #"data: {"choices":[{"delta":{"content":"你好"}}]}"#,
                "data: [DONE]",
                #"data: {"choices":[{"delta":{"content":"不应出现"}}]}"#,
            ]
        )
    )
    let stream = try await client.events(
        profile: try deepSeekProfile(),
        apiKey: "deepseek-secret",
        messages: [.init(role: .user, content: "你好")]
    )
    var events: [ProviderStreamEvent] = []

    for try await event in stream {
        events.append(event)
    }

    #expect(events == [.reasoningDelta("分析"), .textDelta("你好"), .done])
}

@Test func streamingClientRejectsUnsupportedWireFormat() async throws {
    let profile = ProviderProfile(
        displayName: "Anthropic",
        preset: .anthropic,
        baseURL: try #require(ProviderPreset.anthropic.defaultBaseURL),
        modelName: "claude-sonnet-4-20250514",
        isEnabled: true
    )
    let client = ProviderStreamingClient(
        lineStreamer: StubEventLineStreamer(lines: [])
    )

    await #expect(throws: ProviderStreamError.unsupportedProtocol(.anthropic)) {
        _ = try await client.events(
            profile: profile,
            apiKey: "anthropic-secret",
            messages: [.init(role: .user, content: "你好")]
        )
    }
}

private func deepSeekProfile() throws -> ProviderProfile {
    ProviderProfile(
        displayName: "DeepSeek",
        preset: .deepSeek,
        baseURL: try #require(ProviderPreset.deepSeek.defaultBaseURL),
        modelName: "deepseek-chat",
        isEnabled: true
    )
}

private struct StubEventLineStreamer: ProviderEventLineStreaming {
    let lines: [String]

    func lines(
        for request: URLRequest
    ) async throws -> AsyncThrowingStream<String, any Error> {
        AsyncThrowingStream { continuation in
            for line in lines {
                continuation.yield(line)
            }
            continuation.finish()
        }
    }
}
