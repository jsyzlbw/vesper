# iOS Diary Companion Chat UI Plan

> **For Codex:** Execute this plan with test-driven development. Keep the first UI slice to one local conversation and OpenAI-compatible providers.

**Goal:** Replace the empty Chat placeholder with a working persisted conversation UI that streams DeepSeek replies.

**Architecture:** Add a `ConversationRepository` for a default local conversation and message writes. Build a SwiftUI `ChatView` over SwiftData queries. On send, select the first enabled OpenAI-compatible provider, load its Keychain secret, persist the user and assistant messages, and append incoming text deltas from `ProviderStreamingClient`.

**Tech Stack:** Swift 6, SwiftData, SwiftUI, Keychain, SSE

---

### Task 1: Add persisted conversation repository

**Files:**
- Create: `DiaryCompanionCore/Tests/DiaryCompanionCoreTests/ConversationRepositoryTests.swift`
- Create: `DiaryCompanionCore/Sources/DiaryCompanionCore/Persistence/ConversationRepository.swift`

Cover:
- Reuse one default conversation.
- Create ordered messages.
- Append streamed text to an assistant message.

### Task 2: Replace Chat placeholder

**Files:**
- Create: `DiaryCompanion/ChatView.swift`
- Modify: `DiaryCompanion/RootTabView.swift`
- Modify: `DiaryCompanion.xcodeproj/project.pbxproj`

Add:
- Persisted message list.
- Composer and send button.
- Empty state.
- First enabled OpenAI-compatible profile selection.
- Keychain secret loading.
- Streaming text updates.
- Error alert and sending state.

### Task 3: Verify

Run:
- `swift test --package-path DiaryCompanionCore`
- `xcodebuild -project DiaryCompanion.xcodeproj -scheme DiaryCompanion -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath DerivedData build`
- reinstall and relaunch in simulator

Expected: tests pass, app launches full-screen, and Chat shows a composer.
