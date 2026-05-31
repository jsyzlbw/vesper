# iOS Diary Companion Streaming Chat Plan

> **For Codex:** Execute this plan with test-driven development. Never print, persist, or commit API keys.

**Goal:** Add the first real network transport for DeepSeek and other OpenAI-compatible providers, including incremental SSE parsing for normal and reasoning responses.

**Architecture:** Keep request construction in `ProviderRequestFactory`. Add an OpenAI-compatible SSE parser that converts individual `data:` lines into typed stream events. Add a streaming client over `URLSession.bytes(for:)` that validates HTTP status and yields parser events incrementally. Keep provider-specific UI integration for a follow-up slice.

**Tech Stack:** Swift 6, Foundation `URLSession`, SSE, Swift Testing

---

### Task 1: Lock OpenAI-compatible SSE parsing with tests

**Files:**
- Create: `DiaryCompanionCore/Tests/DiaryCompanionCoreTests/OpenAICompatibleSSEParserTests.swift`
- Create: `DiaryCompanionCore/Sources/DiaryCompanionCore/Networking/OpenAICompatibleSSEParser.swift`

**Step 1: Write failing tests**

Cover:
- Parse text deltas.
- Parse DeepSeek reasoning deltas.
- Parse `[DONE]`.
- Ignore blank lines, comments, and usage-only chunks.
- Reject malformed JSON.

**Step 2: Implement the smallest parser**

Expose typed `ProviderStreamEvent` values.

**Step 3: Run focused tests**

Run: `swift test --package-path DiaryCompanionCore --filter OpenAICompatibleSSEParserTests`

Expected: pass.

### Task 2: Add incremental URLSession transport

**Files:**
- Create: `DiaryCompanionCore/Sources/DiaryCompanionCore/Networking/ProviderStreamingClient.swift`

**Step 1: Stream OpenAI-compatible responses**

Build the request with `ProviderRequestFactory`, call `URLSession.bytes(for:)`, validate the status, and parse incoming lines incrementally.

**Step 2: Reject unsupported wire formats explicitly**

Anthropic and Gemini need their own event parsers in later slices. Return a typed error instead of silently misparsing them.

### Task 3: Verify package and simulator app

Run:
- `swift test --package-path DiaryCompanionCore`
- `xcodebuild -project DiaryCompanion.xcodeproj -scheme DiaryCompanion -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath DerivedData build`
- uninstall, install, and relaunch the app in the booted simulator

Expected: tests pass, app builds, and the full-screen layout remains fixed.
