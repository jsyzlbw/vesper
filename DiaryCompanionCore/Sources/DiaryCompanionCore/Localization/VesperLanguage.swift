public enum VesperSupportedLanguage: String, Codable, Sendable {
    case simplifiedChinese
    case english
}

public enum VesperLanguage: String, Codable, CaseIterable, Sendable {
    case followSystem
    case simplifiedChinese
    case english

    public func resolve(preferredLanguages: [String]) -> VesperSupportedLanguage {
        switch self {
        case .followSystem:
            preferredLanguages.first?.lowercased().hasPrefix("zh-hans") == true
                ? .simplifiedChinese
                : .english
        case .simplifiedChinese:
            .simplifiedChinese
        case .english:
            .english
        }
    }
}

public enum VesperAIReplyLanguage {
    public static func containsChinese(_ text: String) -> Bool {
        text.unicodeScalars.contains { scalar in
            (0x4E00...0x9FFF).contains(scalar.value)
        }
    }

    public static func instruction(
        appLanguage: VesperSupportedLanguage,
        latestUserText: String
    ) -> String {
        if appLanguage == .simplifiedChinese || containsChinese(latestUserText) {
            "Reply in Simplified Chinese (简体中文)."
        } else {
            "Reply in English."
        }
    }
}
