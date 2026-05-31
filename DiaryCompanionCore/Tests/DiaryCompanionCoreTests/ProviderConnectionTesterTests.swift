import Foundation
import Testing
@testable import DiaryCompanionCore

@Test func connectionTesterReturnsTextPreview() async throws {
    let tester = ProviderConnectionTester(
        streamEvents: { _, _, _ in
            AsyncThrowingStream { continuation in
                continuation.yield(.reasoningDelta("分析"))
                continuation.yield(.textDelta("连接"))
                continuation.yield(.textDelta("成功"))
                continuation.yield(.done)
                continuation.finish()
            }
        }
    )

    let result = try await tester.test(
        profile: try deepSeekConnectionProfile(),
        apiKey: "deepseek-secret"
    )

    #expect(result.preview == "连接成功")
}

@Test func connectionTesterRejectsEmptyReply() async throws {
    let tester = ProviderConnectionTester(
        streamEvents: { _, _, _ in
            AsyncThrowingStream { continuation in
                continuation.yield(.done)
                continuation.finish()
            }
        }
    )

    await #expect(throws: ProviderConnectionTestError.emptyResponse) {
        _ = try await tester.test(
            profile: try deepSeekConnectionProfile(),
            apiKey: "deepseek-secret"
        )
    }
}

@Test func connectionTesterTimesOut() async throws {
    let tester = ProviderConnectionTester(
        timeoutNanoseconds: 1_000_000,
        streamEvents: { _, _, _ in
            AsyncThrowingStream { _ in }
        }
    )

    await #expect(throws: ProviderConnectionTestError.timedOut) {
        _ = try await tester.test(
            profile: try deepSeekConnectionProfile(),
            apiKey: "deepseek-secret"
        )
    }
}

private func deepSeekConnectionProfile() throws -> ProviderProfile {
    ProviderProfile(
        displayName: "DeepSeek",
        preset: .deepSeek,
        baseURL: try #require(ProviderPreset.deepSeek.defaultBaseURL),
        modelName: "deepseek-v4-flash",
        isEnabled: true
    )
}
