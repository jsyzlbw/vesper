# Provider Endpoint Preview and Connection Test Plan

> **For Codex:** Execute with test-driven development. Do not log credentials.

**Goal:** Clarify the distinction between provider Base URL and final API endpoint, and add an in-app connection test button.

**Architecture:** Expose endpoint resolution from `ProviderRequestFactory` so request construction and Settings preview use the same logic. Add a small `ProviderConnectionTester` that consumes the OpenAI-compatible stream and reports a preview. Use it from the unsaved provider form.

### Task 1: Expose endpoint resolution

**Files:**
- Modify: `DiaryCompanionCore/Tests/DiaryCompanionCoreTests/ProviderRequestFactoryTests.swift`
- Modify: `DiaryCompanionCore/Sources/DiaryCompanionCore/Networking/ProviderRequestFactory.swift`

Cover DeepSeek Base URL `https://api.deepseek.com` resolving to final endpoint `https://api.deepseek.com/chat/completions`.

### Task 2: Add connection tester

**Files:**
- Create: `DiaryCompanionCore/Tests/DiaryCompanionCoreTests/ProviderConnectionTesterTests.swift`
- Create: `DiaryCompanionCore/Sources/DiaryCompanionCore/Networking/ProviderConnectionTester.swift`

Cover successful text aggregation and empty-response rejection.

### Task 3: Add Settings UI controls

**Files:**
- Modify: `DiaryCompanion/ProviderSettingsView.swift`

Show actual endpoint preview and add a test button with loading, success, and failure states.

### Task 4: Verify

Run package tests, simulator build, reinstall, and screenshot verification.
