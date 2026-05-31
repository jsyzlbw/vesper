import DiaryCompanionCore
import SwiftData
import SwiftUI

@main
struct DiaryCompanionApp: App {
    var body: some Scene {
        WindowGroup {
            RootTabView()
        }
        .modelContainer(for: DiarySchema.models)
    }
}
