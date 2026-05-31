# iOS Diary Companion Tool Executor Plan

> **For Codex:** Execute this plan with test-driven development. Keep the first executor slice deliberately small and auditable.

**Goal:** Add the local execution boundary for AI-proposed commands so diary and task writes obey permission policy and always leave an audit trail.

**Architecture:** Represent supported assistant commands as a typed `AssistantToolCall` enum. Add an `AssistantToolExecutor` that asks `ToolPermissionPolicy` for a decision before touching `DiaryRepository`. Return an explicit outcome for automatic execution, confirmation cards, and denied actions. Record redacted audit metadata for each path.

**Tech Stack:** Swift 6, SwiftData, Swift Testing

---

### Task 1: Lock the command execution behavior with tests

**Files:**
- Create: `DiaryCompanionCore/Tests/DiaryCompanionCoreTests/AssistantToolExecutorTests.swift`

**Step 1: Write failing tests**

Cover:
- Automatic diary capability creates a diary entry and success audit.
- Default task capability returns confirmation required without creating a task and records a pending audit.
- Denied task capability returns denied without creating a task and records a denied audit.
- Confirmed task execution writes the task and records a success audit.

**Step 2: Run focused tests and verify failure**

Run: `swift test --package-path DiaryCompanionCore --filter AssistantToolExecutorTests`

Expected: compilation failure because executor types do not exist yet.

### Task 2: Implement the typed executor

**Files:**
- Modify: `DiaryCompanionCore/Sources/DiaryCompanionCore/Models/DiaryModels.swift`
- Create: `DiaryCompanionCore/Sources/DiaryCompanionCore/Tools/AssistantToolExecutor.swift`

**Step 1: Add pending audit result**

Add `pendingConfirmation` to `ToolExecutionResult`.

**Step 2: Add typed calls and explicit outcomes**

Support `createDiaryEntry` and `createTask` first.

**Step 3: Add executor behavior**

Implement normal permission evaluation and explicit confirmed execution.

**Step 4: Run focused tests**

Run: `swift test --package-path DiaryCompanionCore --filter AssistantToolExecutorTests`

Expected: pass.

### Task 3: Verify the package and simulator app

Run:
- `swift test --package-path DiaryCompanionCore`
- `xcodebuild -project DiaryCompanion.xcodeproj -scheme DiaryCompanion -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath DerivedData build`
- `xcrun simctl install booted DerivedData/Build/Products/Debug-iphonesimulator/DiaryCompanion.app`
- `xcrun simctl launch --terminate-running-process booted com.liangbowenbill.DiaryCompanion`

Expected: tests pass, build succeeds, and app launches.
