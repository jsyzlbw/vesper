import Foundation

public enum ProviderStreamEvent: Equatable, Sendable {
    case textDelta(String)
    case reasoningDelta(String)
    case done
}

public enum ProviderStreamError: Error, Equatable, Sendable {
    case invalidEventData
    case invalidResponse
    case httpStatus(Int)
    case unsupportedProtocol(ProviderProtocolKind)
}

extension ProviderStreamError: LocalizedError {
    public var errorDescription: String? {
        localizedDescription(language: .simplifiedChinese)
    }

    public func localizedDescription(language: VesperSupportedLanguage) -> String {
        switch (language, self) {
        case (.simplifiedChinese, .invalidEventData):
            "AI 服务返回了无法解析的数据。"
        case (.simplifiedChinese, .invalidResponse):
            "AI 服务返回了无效响应，请检查 Endpoint。"
        case let (.simplifiedChinese, .httpStatus(statusCode)):
            "AI 服务请求失败（HTTP \(statusCode)），请检查 API Key、Endpoint 和模型名称。"
        case (.simplifiedChinese, .unsupportedProtocol):
            "当前对话暂不支持所选服务商协议。"
        case (.english, .invalidEventData):
            "The AI service returned data that could not be parsed."
        case (.english, .invalidResponse):
            "The AI service returned an invalid response. Check the endpoint."
        case let (.english, .httpStatus(statusCode)):
            "The AI service request failed (HTTP \(statusCode)). Check the API key, endpoint, and model name."
        case (.english, .unsupportedProtocol):
            "Chat does not support the selected provider protocol yet."
        }
    }
}

public struct OpenAICompatibleSSEParser: Sendable {
    public init() {}

    public func parse(line: String) throws -> ProviderStreamEvent? {
        guard !line.isEmpty, !line.hasPrefix(":") else {
            return nil
        }
        guard line.hasPrefix("data:") else {
            return nil
        }

        let payload = line
            .dropFirst("data:".count)
            .trimmingCharacters(in: .whitespaces)
        if payload == "[DONE]" {
            return .done
        }
        guard let data = payload.data(using: .utf8) else {
            throw ProviderStreamError.invalidEventData
        }

        let chunk: OpenAICompatibleStreamChunk
        do {
            chunk = try JSONDecoder().decode(
                OpenAICompatibleStreamChunk.self,
                from: data
            )
        } catch {
            throw ProviderStreamError.invalidEventData
        }

        guard let delta = chunk.choices.first?.delta else {
            return nil
        }
        if let reasoning = delta.reasoningContent, !reasoning.isEmpty {
            return .reasoningDelta(reasoning)
        }
        if let content = delta.content, !content.isEmpty {
            return .textDelta(content)
        }
        return nil
    }
}

private struct OpenAICompatibleStreamChunk: Decodable {
    let choices: [Choice]

    struct Choice: Decodable {
        let delta: Delta
    }

    struct Delta: Decodable {
        let content: String?
        let reasoningContent: String?

        enum CodingKeys: String, CodingKey {
            case content
            case reasoningContent = "reasoning_content"
        }
    }
}
