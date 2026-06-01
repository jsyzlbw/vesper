import DiaryCompanionCore
import SwiftData
import SwiftUI

@main
struct DiaryCompanionApp: App {
    @AppStorage("vesper.appLanguage")
    private var appLanguageRawValue = VesperLanguage.followSystem.rawValue

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environment(\.vesperLocalization, localization)
                .environment(\.locale, localization.locale)
        }
        .modelContainer(for: DiarySchema.models)
    }

    private var localization: VesperLocalizationContext {
        let language = VesperLanguage(rawValue: appLanguageRawValue) ?? .followSystem
        return VesperLocalizationContext(
            language: language.resolve(preferredLanguages: Locale.preferredLanguages)
        )
    }
}
