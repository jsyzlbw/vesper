import Foundation

public protocol ProviderEventLineStreaming: Sendable {
    func lines(
        for request: URLRequest
    ) async throws -> AsyncThrowingStream<String, any Error>
}

public struct URLSessionEventLineStreamer: ProviderEventLineStreaming {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func lines(
        for request: URLRequest
    ) async throws -> AsyncThrowingStream<String, any Error> {
        let (bytes, response) = try await session.bytes(for: request)
        guard let response = response as? HTTPURLResponse else {
            throw ProviderStreamError.invalidResponse
        }
        guard (200..<300).contains(response.statusCode) else {
            throw ProviderStreamError.httpStatus(response.statusCode)
        }

        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    for try await line in bytes.lines {
                        continuation.yield(line)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }
}

public struct ProviderStreamingClient: Sendable {
    private let requestFactory: ProviderRequestFactory
    private let lineStreamer: any ProviderEventLineStreaming

    public init(
        requestFactory: ProviderRequestFactory = ProviderRequestFactory(),
        lineStreamer: any ProviderEventLineStreaming = URLSessionEventLineStreamer()
    ) {
        self.requestFactory = requestFactory
        self.lineStreamer = lineStreamer
    }

    public func events(
        profile: ProviderProfile,
        apiKey: String,
        messages: [ChatMessage],
        maxOutputTokens: Int = 1_024
    ) async throws -> AsyncThrowingStream<ProviderStreamEvent, any Error> {
        guard profile.protocolKind == .openAI
                || profile.protocolKind == .openAICompatible
        else {
            throw ProviderStreamError.unsupportedProtocol(profile.protocolKind)
        }

        let request = try requestFactory.makeStreamingRequest(
            profile: profile,
            apiKey: apiKey,
            messages: messages,
            maxOutputTokens: maxOutputTokens
        )
        let lines = try await lineStreamer.lines(for: request)
        let parser = OpenAICompatibleSSEParser()

        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    for try await line in lines {
                        guard let event = try parser.parse(line: line) else {
                            continue
                        }
                        continuation.yield(event)
                        if event == .done {
                            continuation.finish()
                            return
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }
}
