import Foundation

public struct ProviderConnectionTestResult: Equatable, Sendable {
    public let preview: String

    public init(preview: String) {
        self.preview = preview
    }
}

public enum ProviderConnectionTestError: Error, Equatable, Sendable {
    case emptyResponse
    case timedOut
}

extension ProviderConnectionTestError: LocalizedError {
    public var errorDescription: String? {
        localizedDescription(language: .simplifiedChinese)
    }

    public func localizedDescription(language: VesperSupportedLanguage) -> String {
        switch (language, self) {
        case (.simplifiedChinese, .emptyResponse):
            "服务已响应，但没有返回文本。"
        case (.simplifiedChinese, .timedOut):
            "连接测试超时，请检查网络、Base URL 和模型名称。"
        case (.english, .emptyResponse):
            "The service responded but did not return any text."
        case (.english, .timedOut):
            "The connection test timed out. Check the network, base URL, and model name."
        }
    }
}

public struct ProviderConnectionTester: Sendable {
    public typealias StreamEvents = @Sendable (
        ProviderProfile,
        String,
        [ChatMessage]
    ) async throws -> AsyncThrowingStream<ProviderStreamEvent, any Error>

    private let streamEvents: StreamEvents
    private let timeoutNanoseconds: UInt64

    public init(
        timeoutNanoseconds: UInt64 = 15_000_000_000,
        streamEvents: @escaping StreamEvents = { profile, apiKey, messages in
            try await ProviderStreamingClient().events(
                profile: profile,
                apiKey: apiKey,
                messages: messages
            )
        }
    ) {
        self.timeoutNanoseconds = timeoutNanoseconds
        self.streamEvents = streamEvents
    }

    public func test(
        profile: ProviderProfile,
        apiKey: String
    ) async throws -> ProviderConnectionTestResult {
        try await withThrowingTaskGroup(
            of: ProviderConnectionTestResult.self
        ) { group in
            group.addTask {
                try await collectPreview(
                    streamEvents: streamEvents,
                    profile: profile,
                    apiKey: apiKey
                )
            }
            group.addTask {
                try await Task.sleep(nanoseconds: timeoutNanoseconds)
                throw ProviderConnectionTestError.timedOut
            }

            guard let result = try await group.next() else {
                throw ProviderConnectionTestError.emptyResponse
            }
            group.cancelAll()
            return result
        }
    }

    private func collectPreview(
        streamEvents: StreamEvents,
        profile: ProviderProfile,
        apiKey: String
    ) async throws -> ProviderConnectionTestResult {
        let stream = try await streamEvents(
            profile,
            apiKey,
            [.init(role: .user, content: "Reply only with: connected")]
        )
        var preview = ""

        for try await event in stream {
            switch event {
            case let .textDelta(text):
                preview.append(text)
            case .reasoningDelta:
                continue
            case .done:
                break
            }
        }

        let trimmed = preview.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw ProviderConnectionTestError.emptyResponse
        }
        return ProviderConnectionTestResult(
            preview: String(trimmed.prefix(80))
        )
    }
}
