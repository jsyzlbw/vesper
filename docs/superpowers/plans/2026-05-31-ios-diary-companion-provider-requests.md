# iOS Diary Companion Provider Request Factories Plan

> **For Codex:** Execute this plan with test-driven development. Build request objects only; do not send real API calls.

**Goal:** Add a small, testable networking boundary that constructs streaming chat requests for OpenAI, Anthropic, Gemini, DeepSeek, SiliconFlow, and custom OpenAI-compatible profiles.

**Architecture:** Add shared chat message value types and one `ProviderRequestFactory`. Select the wire format from `ProviderProfile.protocolKind`. Reuse the OpenAI-compatible payload for DeepSeek, SiliconFlow, and Custom while keeping OpenAI selectable as its own protocol kind. Keep credentials in request headers only and leave transport, retries, response parsing, and tool calling for later batches.

**Tech Stack:** Swift 6, Foundation `URLRequest`, Swift Testing

---

### Task 1: Lock the provider-specific request contracts with tests

**Files:**
- Create: `DiaryCompanionCore/Tests/DiaryCompanionCoreTests/ProviderRequestFactoryTests.swift`

**Step 1: Write failing tests**

Cover:
- OpenAI streaming chat completions URL, bearer header, and JSON body.
- DeepSeek, SiliconFlow, and Custom OpenAI-compatible URLs.
- Anthropic Messages URL, `x-api-key`, `anthropic-version`, `max_tokens`, separated system prompt, and streaming flag.
- Gemini `streamGenerateContent?alt=sse` URL, `x-goog-api-key`, assistant-to-`model` role mapping, and separated system instruction.

**Step 2: Run the focused tests and verify failure**

Run: `swift test --package-path DiaryCompanionCore --filter ProviderRequestFactoryTests`

Expected: failure because request models and `ProviderRequestFactory` do not exist yet.

### Task 2: Implement the smallest request factory that satisfies the contracts

**Files:**
- Create: `DiaryCompanionCore/Sources/DiaryCompanionCore/Networking/ProviderRequestFactory.swift`

**Step 1: Add shared request input types**

Add `ChatRole` and `ChatMessage`.

**Step 2: Implement protocol-specific builders**

Add `ProviderRequestFactory.makeStreamingRequest(profile:apiKey:messages:maxOutputTokens:)`.

Use:
- `{baseURL}/chat/completions` for OpenAI and OpenAI-compatible profiles.
- `{baseURL}/messages` for Anthropic.
- `{baseURL}/models/{model}:streamGenerateContent?alt=sse` for Gemini.

**Step 3: Run the focused tests**

Run: `swift test --package-path DiaryCompanionCore --filter ProviderRequestFactoryTests`

Expected: pass.

### Task 3: Verify the package and simulator app

**Files:**
- Modify only if verification reveals an issue.

**Step 1: Run package tests**

Run: `swift test --package-path DiaryCompanionCore`

Expected: all tests pass.

**Step 2: Build the iOS app**

Run: `xcodebuild -project DiaryCompanion.xcodeproj -scheme DiaryCompanion -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath DerivedData build`

Expected: `BUILD SUCCEEDED`.

**Step 3: Install and launch in the booted simulator**

Run:
- `xcrun simctl install booted DerivedData/Build/Products/Debug-iphonesimulator/DiaryCompanion.app`
- `xcrun simctl launch --terminate-running-process booted com.liangbowenbill.DiaryCompanion`

Expected: app launches successfully.
