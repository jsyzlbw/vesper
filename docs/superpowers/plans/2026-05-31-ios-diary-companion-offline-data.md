# iOS Diary Companion Offline Data Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a local-first SwiftData persistence layer for the first-version diary records and connect the Timeline tab to stored diary entries.

**Architecture:** Define SwiftData `@Model` records separately from transport-friendly value models. Keep all model-container creation in one factory and put writes behind a `@MainActor` repository so UI code does not spread `ModelContext` behavior across features. Configure the App with the local model schema now; CloudKit capability configuration remains a signed-device follow-up.

**Tech Stack:** Swift 6, SwiftData, SwiftUI, Swift Package Manager, Xcode 26.5

---

## File Structure

```text
DiaryCompanionCore/
├── Sources/
│   └── DiaryCompanionCore/
│       └── Persistence/
│           ├── DiaryModelContainerFactory.swift
│           ├── DiaryRepository.swift
│           └── PersistedModels.swift
└── Tests/
    └── DiaryCompanionCoreTests/
        ├── DiaryRepositoryTests.swift
        └── PersistenceSchemaTests.swift
DiaryCompanion/
├── DiaryCompanionApp.swift
└── RootTabView.swift
```

## Task 1: SwiftData schema

**Files:**
- Create: `DiaryCompanionCore/Sources/DiaryCompanionCore/Persistence/PersistedModels.swift`
- Create: `DiaryCompanionCore/Sources/DiaryCompanionCore/Persistence/DiaryModelContainerFactory.swift`
- Create: `DiaryCompanionCore/Tests/DiaryCompanionCoreTests/PersistenceSchemaTests.swift`

- [ ] **Step 1: Write the failing schema test**

Create `DiaryCompanionCore/Tests/DiaryCompanionCoreTests/PersistenceSchemaTests.swift`:

```swift
import Foundation
import SwiftData
import Testing
@testable import DiaryCompanionCore

@MainActor
@Test func inMemorySchemaStoresFirstVersionRecords() throws {
    let container = try DiaryModelContainerFactory.make(inMemory: true)
    let context = container.mainContext
    let now = Date(timeIntervalSince1970: 0)

    context.insert(ConversationRecord(title: "日常", createdAt: now, updatedAt: now))
    context.insert(MessageRecord(conversationID: UUID(), role: "user", content: "今天完成设计", createdAt: now))
    context.insert(DiaryRecord(date: now, content: "今天完成设计", tags: ["工作"]))
    context.insert(TaskRecord(title: "继续开发", notes: "", dueAt: now))
    context.insert(ReminderRecord(title: "吃药", body: "记得吃药", fireDate: now))
    context.insert(WeightRecord(date: now, kilograms: 70.5))
    context.insert(MealRecord(mealType: "早餐", date: now, detail: "咖啡和鸡蛋"))
    context.insert(MedicationRecord(name: "鱼油", date: now, status: "已服用"))
    context.insert(DailySummaryRecord(date: now, content: "完成了基础设计"))
    context.insert(ToolAuditRecord(toolName: "createTask", parameterSummaryData: Data(), decision: "allow", result: "success", createdAt: now))
    context.insert(ProviderProfileRecord(displayName: "OpenAI", presetID: "openai", baseURL: "https://api.openai.com/v1", modelName: "gpt-5", isEnabled: true))
    try context.save()

    #expect(try context.fetchCount(FetchDescriptor<ConversationRecord>()) == 1)
    #expect(try context.fetchCount(FetchDescriptor<MessageRecord>()) == 1)
    #expect(try context.fetchCount(FetchDescriptor<DiaryRecord>()) == 1)
    #expect(try context.fetchCount(FetchDescriptor<TaskRecord>()) == 1)
    #expect(try context.fetchCount(FetchDescriptor<ReminderRecord>()) == 1)
    #expect(try context.fetchCount(FetchDescriptor<WeightRecord>()) == 1)
    #expect(try context.fetchCount(FetchDescriptor<MealRecord>()) == 1)
    #expect(try context.fetchCount(FetchDescriptor<MedicationRecord>()) == 1)
    #expect(try context.fetchCount(FetchDescriptor<DailySummaryRecord>()) == 1)
    #expect(try context.fetchCount(FetchDescriptor<ToolAuditRecord>()) == 1)
    #expect(try context.fetchCount(FetchDescriptor<ProviderProfileRecord>()) == 1)
}
```

- [ ] **Step 2: Run the schema test to verify it fails**

Run:

```bash
swift test --package-path DiaryCompanionCore --filter PersistenceSchemaTests
```

Expected: FAIL because `DiaryModelContainerFactory` and the persisted record types do not exist.

- [ ] **Step 3: Implement persisted models**

Create `DiaryCompanionCore/Sources/DiaryCompanionCore/Persistence/PersistedModels.swift`:

```swift
import Foundation
import SwiftData

@Model public final class ConversationRecord {
    @Attribute(.unique) public var id: UUID
    public var title: String
    public var createdAt: Date
    public var updatedAt: Date
    public init(id: UUID = UUID(), title: String, createdAt: Date = Date(), updatedAt: Date = Date()) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

@Model public final class MessageRecord {
    @Attribute(.unique) public var id: UUID
    public var conversationID: UUID
    public var role: String
    public var content: String
    public var createdAt: Date
    public init(id: UUID = UUID(), conversationID: UUID, role: String, content: String, createdAt: Date = Date()) {
        self.id = id
        self.conversationID = conversationID
        self.role = role
        self.content = content
        self.createdAt = createdAt
    }
}

@Model public final class DiaryRecord {
    @Attribute(.unique) public var id: UUID
    public var date: Date
    public var content: String
    public var tags: [String]
    public var sourceMessageID: UUID?
    public init(id: UUID = UUID(), date: Date, content: String, tags: [String] = [], sourceMessageID: UUID? = nil) {
        self.id = id
        self.date = date
        self.content = content
        self.tags = tags
        self.sourceMessageID = sourceMessageID
    }
}

@Model public final class TaskRecord {
    @Attribute(.unique) public var id: UUID
    public var title: String
    public var notes: String
    public var dueAt: Date?
    public var isCompleted: Bool
    public var sourceMessageID: UUID?
    public init(id: UUID = UUID(), title: String, notes: String = "", dueAt: Date? = nil, isCompleted: Bool = false, sourceMessageID: UUID? = nil) {
        self.id = id
        self.title = title
        self.notes = notes
        self.dueAt = dueAt
        self.isCompleted = isCompleted
        self.sourceMessageID = sourceMessageID
    }
}

@Model public final class ReminderRecord {
    @Attribute(.unique) public var id: UUID
    public var taskID: UUID?
    public var title: String
    public var body: String
    public var fireDate: Date
    public var repeats: Bool
    public var isScheduled: Bool
    public init(id: UUID = UUID(), taskID: UUID? = nil, title: String, body: String, fireDate: Date, repeats: Bool = false, isScheduled: Bool = false) {
        self.id = id
        self.taskID = taskID
        self.title = title
        self.body = body
        self.fireDate = fireDate
        self.repeats = repeats
        self.isScheduled = isScheduled
    }
}

@Model public final class WeightRecord {
    @Attribute(.unique) public var id: UUID
    public var date: Date
    public var kilograms: Double
    public init(id: UUID = UUID(), date: Date, kilograms: Double) {
        self.id = id
        self.date = date
        self.kilograms = kilograms
    }
}

@Model public final class MealRecord {
    @Attribute(.unique) public var id: UUID
    public var mealType: String
    public var date: Date
    public var detail: String
    public var aiSuggestion: String?
    public init(id: UUID = UUID(), mealType: String, date: Date, detail: String, aiSuggestion: String? = nil) {
        self.id = id
        self.mealType = mealType
        self.date = date
        self.detail = detail
        self.aiSuggestion = aiSuggestion
    }
}

@Model public final class MedicationRecord {
    @Attribute(.unique) public var id: UUID
    public var name: String
    public var date: Date
    public var status: String
    public var notes: String
    public init(id: UUID = UUID(), name: String, date: Date, status: String, notes: String = "") {
        self.id = id
        self.name = name
        self.date = date
        self.status = status
        self.notes = notes
    }
}

@Model public final class DailySummaryRecord {
    @Attribute(.unique) public var id: UUID
    public var date: Date
    public var content: String
    public var createdAt: Date
    public init(id: UUID = UUID(), date: Date, content: String, createdAt: Date = Date()) {
        self.id = id
        self.date = date
        self.content = content
        self.createdAt = createdAt
    }
}

@Model public final class ToolAuditRecord {
    @Attribute(.unique) public var id: UUID
    public var toolName: String
    public var parameterSummaryData: Data
    public var decision: String
    public var result: String
    public var createdAt: Date
    public init(id: UUID = UUID(), toolName: String, parameterSummaryData: Data, decision: String, result: String, createdAt: Date = Date()) {
        self.id = id
        self.toolName = toolName
        self.parameterSummaryData = parameterSummaryData
        self.decision = decision
        self.result = result
        self.createdAt = createdAt
    }
}

@Model public final class ProviderProfileRecord {
    @Attribute(.unique) public var id: UUID
    public var displayName: String
    public var presetID: String
    public var baseURL: String
    public var modelName: String
    public var isEnabled: Bool
    public init(id: UUID = UUID(), displayName: String, presetID: String, baseURL: String, modelName: String, isEnabled: Bool) {
        self.id = id
        self.displayName = displayName
        self.presetID = presetID
        self.baseURL = baseURL
        self.modelName = modelName
        self.isEnabled = isEnabled
    }
}

public enum DiarySchema {
    public static var models: [any PersistentModel.Type] {
        [
            ConversationRecord.self,
            MessageRecord.self,
            DiaryRecord.self,
            TaskRecord.self,
            ReminderRecord.self,
            WeightRecord.self,
            MealRecord.self,
            MedicationRecord.self,
            DailySummaryRecord.self,
            ToolAuditRecord.self,
            ProviderProfileRecord.self,
        ]
    }
}
```

- [ ] **Step 4: Implement model-container creation**

Create `DiaryCompanionCore/Sources/DiaryCompanionCore/Persistence/DiaryModelContainerFactory.swift`:

```swift
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
```

- [ ] **Step 5: Run the schema test to verify it passes**

Run:

```bash
swift test --package-path DiaryCompanionCore --filter PersistenceSchemaTests
```

Expected: PASS with `1 test passed`.

- [ ] **Step 6: Commit**

```bash
git add DiaryCompanionCore
git commit -m "feat: add SwiftData persistence schema"
```

## Task 2: Diary repository

**Files:**
- Create: `DiaryCompanionCore/Sources/DiaryCompanionCore/Persistence/DiaryRepository.swift`
- Create: `DiaryCompanionCore/Tests/DiaryCompanionCoreTests/DiaryRepositoryTests.swift`

- [ ] **Step 1: Write failing repository tests**

Create `DiaryCompanionCore/Tests/DiaryCompanionCoreTests/DiaryRepositoryTests.swift`:

```swift
import Foundation
import Testing
@testable import DiaryCompanionCore

@MainActor
@Test func repositoryCreatesDiaryEntriesAndTasks() throws {
    let container = try DiaryModelContainerFactory.make(inMemory: true)
    let repository = DiaryRepository(context: container.mainContext)
    let now = Date(timeIntervalSince1970: 0)

    try repository.createDiaryEntry(date: now, content: "今天完成持久化", tags: ["工作"])
    try repository.createTask(title: "继续实现聊天", dueAt: now)

    #expect(try repository.fetchDiaryEntries().map(\.content) == ["今天完成持久化"])
    #expect(try repository.fetchTasks().map(\.title) == ["继续实现聊天"])
}

@MainActor
@Test func repositoryPersistsRedactedAuditLog() throws {
    let container = try DiaryModelContainerFactory.make(inMemory: true)
    let repository = DiaryRepository(context: container.mainContext)
    let log = ToolAuditLog(
        toolName: "configureProvider",
        parameters: ["provider": "openai", "apiKey": "sk-secret"],
        decision: .allow,
        result: .success
    )

    try repository.saveAuditLog(log)

    let stored = try #require(repository.fetchAuditLogs().first)
    let parameters = try JSONDecoder().decode([String: String].self, from: stored.parameterSummaryData)
    #expect(parameters["provider"] == "openai")
    #expect(parameters["apiKey"] == "<redacted>")
}
```

- [ ] **Step 2: Run repository tests to verify they fail**

Run:

```bash
swift test --package-path DiaryCompanionCore --filter DiaryRepositoryTests
```

Expected: FAIL because `DiaryRepository` does not exist.

- [ ] **Step 3: Implement repository writes and fetches**

Create `DiaryCompanionCore/Sources/DiaryCompanionCore/Persistence/DiaryRepository.swift`:

```swift
import Foundation
import SwiftData

@MainActor
public final class DiaryRepository {
    private let context: ModelContext

    public init(context: ModelContext) {
        self.context = context
    }

    @discardableResult
    public func createDiaryEntry(
        date: Date,
        content: String,
        tags: [String] = [],
        sourceMessageID: UUID? = nil
    ) throws -> DiaryRecord {
        let record = DiaryRecord(
            date: date,
            content: content,
            tags: tags,
            sourceMessageID: sourceMessageID
        )
        context.insert(record)
        try context.save()
        return record
    }

    @discardableResult
    public func createTask(
        title: String,
        notes: String = "",
        dueAt: Date? = nil,
        sourceMessageID: UUID? = nil
    ) throws -> TaskRecord {
        let record = TaskRecord(
            title: title,
            notes: notes,
            dueAt: dueAt,
            sourceMessageID: sourceMessageID
        )
        context.insert(record)
        try context.save()
        return record
    }

    public func saveAuditLog(_ log: ToolAuditLog) throws {
        let data = try JSONEncoder().encode(log.parameterSummary)
        context.insert(
            ToolAuditRecord(
                id: log.id,
                toolName: log.toolName,
                parameterSummaryData: data,
                decision: log.decision.rawValue,
                result: log.result.rawValue,
                createdAt: log.createdAt
            )
        )
        try context.save()
    }

    public func fetchDiaryEntries() throws -> [DiaryRecord] {
        var descriptor = FetchDescriptor<DiaryRecord>()
        descriptor.sortBy = [SortDescriptor(\.date, order: .reverse)]
        return try context.fetch(descriptor)
    }

    public func fetchTasks() throws -> [TaskRecord] {
        var descriptor = FetchDescriptor<TaskRecord>()
        descriptor.sortBy = [SortDescriptor(\.dueAt)]
        return try context.fetch(descriptor)
    }

    public func fetchAuditLogs() throws -> [ToolAuditRecord] {
        var descriptor = FetchDescriptor<ToolAuditRecord>()
        descriptor.sortBy = [SortDescriptor(\.createdAt, order: .reverse)]
        return try context.fetch(descriptor)
    }
}
```

- [ ] **Step 4: Run repository tests to verify they pass**

Run:

```bash
swift test --package-path DiaryCompanionCore --filter DiaryRepositoryTests
```

Expected: PASS with `2 tests passed`.

- [ ] **Step 5: Commit**

```bash
git add DiaryCompanionCore
git commit -m "feat: add local diary repository"
```

## Task 3: Connect the App to SwiftData

**Files:**
- Modify: `DiaryCompanion/DiaryCompanionApp.swift`
- Modify: `DiaryCompanion/RootTabView.swift`

- [ ] **Step 1: Attach the model container**

Update `DiaryCompanion/DiaryCompanionApp.swift`:

```swift
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
```

- [ ] **Step 2: Connect Timeline to diary records**

Replace `DiaryCompanion/RootTabView.swift` with:

```swift
import DiaryCompanionCore
import SwiftData
import SwiftUI

struct RootTabView: View {
    var body: some View {
        TabView {
            NavigationStack {
                ContentUnavailableView(
                    "开始对话",
                    systemImage: "bubble.left.and.bubble.right",
                    description: Text("连接 AI Provider 后，通过自然语言记录生活。")
                )
                .navigationTitle("对话")
            }
            .tabItem {
                Label("对话", systemImage: "bubble.left.and.bubble.right")
            }

            NavigationStack {
                TimelineView()
                    .navigationTitle("时间线")
            }
            .tabItem {
                Label("时间线", systemImage: "clock")
            }

            NavigationStack {
                List {
                    Section("AI Provider") {
                        Text("尚未配置")
                    }
                    Section("权限") {
                        Text("默认执行前确认")
                    }
                }
                .navigationTitle("设置")
            }
            .tabItem {
                Label("设置", systemImage: "gearshape")
            }

            NavigationStack {
                ContentUnavailableView(
                    "暂无审计记录",
                    systemImage: "checklist",
                    description: Text("AI 的工具调用记录会显示在这里。")
                )
                .navigationTitle("审计")
            }
            .tabItem {
                Label("审计", systemImage: "checklist")
            }
        }
    }
}

private struct TimelineView: View {
    @Query(sort: \DiaryRecord.date, order: .reverse)
    private var entries: [DiaryRecord]

    var body: some View {
        if entries.isEmpty {
            ContentUnavailableView(
                "暂无记录",
                systemImage: "clock.arrow.circlepath",
                description: Text("AI 保存的日记、任务和总结会出现在这里。")
            )
        } else {
            List(entries) { entry in
                VStack(alignment: .leading, spacing: 6) {
                    Text(entry.date, style: .date)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(entry.content)
                }
            }
        }
    }
}

#Preview {
    RootTabView()
        .modelContainer(for: DiarySchema.models, inMemory: true)
}
```

- [ ] **Step 3: Build the App**

Run:

```bash
xcodebuild -project DiaryCompanion.xcodeproj \
  -scheme DiaryCompanion \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -derivedDataPath DerivedData \
  build
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Commit**

```bash
git add DiaryCompanion
git commit -m "feat: connect timeline to SwiftData"
```

## Task 4: Full verification

**Files:**
- No new files

- [ ] **Step 1: Run complete tests**

Run:

```bash
swift test --package-path DiaryCompanionCore
```

Expected: PASS with `15 tests passed`.

- [ ] **Step 2: Install and launch the rebuilt App**

Run:

```bash
xcrun simctl install booted DerivedData/Build/Products/Debug-iphonesimulator/DiaryCompanion.app
xcrun simctl launch --terminate-running-process booted com.liangbowenbill.DiaryCompanion
```

Expected: launch command prints `com.liangbowenbill.DiaryCompanion: <pid>`.

- [ ] **Step 3: Check repository status**

Run:

```bash
git diff --check
git status --short
```

Expected: no whitespace errors and no uncommitted files.

