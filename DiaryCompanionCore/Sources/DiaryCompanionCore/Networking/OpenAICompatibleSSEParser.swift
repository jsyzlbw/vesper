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
