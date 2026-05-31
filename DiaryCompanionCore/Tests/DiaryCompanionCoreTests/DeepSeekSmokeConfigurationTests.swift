import Testing
@testable import DiaryCompanionCore

@Test func deepSeekSmokeUsesDedicatedKeychainItemAndDefaultProfile() {
    let profile = DeepSeekSmokeConfiguration.profile

    #expect(DeepSeekSmokeConfiguration.keychainService == "com.liangbowenbill.DiaryCompanion.smoke")
    #expect(DeepSeekSmokeConfiguration.keychainAccount == "deepseek")
    #expect(profile.preset == .deepSeek)
    #expect(profile.modelName == "deepseek-chat")
    #expect(profile.baseURL.absoluteString == "https://api.deepseek.com")
}
