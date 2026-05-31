import SwiftData

public enum DiaryModelContainerFactory {
    @MainActor
    public static func make(inMemory: Bool = false) throws -> ModelContainer {
        let schema = Schema(DiarySchema.models)
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: inMemory
        )
        return try ModelContainer(
            for: schema,
            configurations: [configuration]
        )
    }
}
