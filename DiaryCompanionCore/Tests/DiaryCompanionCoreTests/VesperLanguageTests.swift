import Testing
@testable import DiaryCompanionCore

@Test(arguments: [
    (VesperLanguage.simplifiedChinese, VesperSupportedLanguage.simplifiedChinese),
    (VesperLanguage.english, VesperSupportedLanguage.english),
])
func explicitLanguageSelectionIgnoresSystemLanguage(
    selection: VesperLanguage,
    expected: VesperSupportedLanguage
) {
    #expect(selection.resolve(preferredLanguages: ["zh-Hant-TW"]) == expected)
}

@Test func followsSimplifiedChineseSystemLanguage() {
    #expect(
        VesperLanguage.followSystem.resolve(preferredLanguages: ["zh-Hans-CN"])
            == .simplifiedChinese
    )
}

@Test(arguments: [
    ["en-US"],
    ["zh-Hant-TW"],
    ["fr-FR"],
    [],
])
func unsupportedSystemLanguageFallsBackToEnglish(preferredLanguages: [String]) {
    #expect(
        VesperLanguage.followSystem.resolve(preferredLanguages: preferredLanguages)
            == .english
    )
}

@Test(arguments: [
    ("明天提醒我喝水", true),
    ("Reminder: 喝水", true),
    ("Remind me tomorrow", false),
])
func detectsChineseHanCharacters(text: String, expected: Bool) {
    #expect(VesperAIReplyLanguage.containsChinese(text) == expected)
}

@Test func chineseMessageOverridesEnglishAIReplyLanguage() {
    #expect(
        VesperAIReplyLanguage.instruction(
            appLanguage: .english,
            latestUserText: "明天提醒我喝水"
        ).contains("简体中文")
    )
}

@Test func englishMessageUsesEnglishAIReplyLanguage() {
    #expect(
        VesperAIReplyLanguage.instruction(
            appLanguage: .english,
            latestUserText: "Remind me to drink water tomorrow."
        ).contains("English")
    )
}

@Test func simplifiedChineseAppLanguageUsesSimplifiedChineseAIReplyLanguage() {
    #expect(
        VesperAIReplyLanguage.instruction(
            appLanguage: .simplifiedChinese,
            latestUserText: "Remind me to drink water tomorrow."
        ).contains("简体中文")
    )
}
