import Foundation

public enum DeepSeekSmokeConfiguration {
    public static let keychainService = "com.liangbowenbill.DiaryCompanion.smoke"
    public static let keychainAccount = "deepseek"

    public static var profile: ProviderProfile {
        ProviderProfile(
            displayName: "DeepSeek Smoke Test",
            preset: .deepSeek,
            baseURL: ProviderPreset.deepSeek.defaultBaseURL!,
            modelName: "deepseek-chat",
            isEnabled: true
        )
    }
}
