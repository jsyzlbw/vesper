import Foundation
import Testing
@testable import DiaryCompanionCore

@Test func presetsIncludeRequiredProviders() {
    #expect(Set(ProviderPreset.allCases.map(\.id)) == [
        "openai", "anthropic", "gemini", "deepseek", "siliconflow", "custom",
    ])
}

@Test func deepSeekUsesOpenAICompatibleProtocol() {
    #expect(ProviderPreset.deepSeek.protocolKind == .openAICompatible)
    #expect(ProviderPreset.deepSeek.defaultBaseURL?.absoluteString == "https://api.deepseek.com")
}

@Test func siliconFlowUsesOpenAICompatibleProtocol() {
    #expect(ProviderPreset.siliconFlow.protocolKind == .openAICompatible)
    #expect(ProviderPreset.siliconFlow.defaultBaseURL?.absoluteString == "https://api.siliconflow.cn/v1")
}

@Test func customProfilePreservesUserConfiguration() throws {
    let profile = ProviderProfile(
        displayName: "Campus Proxy",
        preset: .custom,
        baseURL: try #require(URL(string: "https://example.com/v1")),
        modelName: "example-model",
        isEnabled: true
    )

    #expect(profile.displayName == "Campus Proxy")
    #expect(profile.protocolKind == .openAICompatible)
    #expect(profile.baseURL.absoluteString == "https://example.com/v1")
    #expect(profile.modelName == "example-model")
}
