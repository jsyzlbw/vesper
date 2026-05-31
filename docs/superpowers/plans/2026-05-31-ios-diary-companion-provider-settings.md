# iOS Diary Companion Provider Settings Plan

> **For Codex:** Execute this plan with test-driven development. Provider metadata belongs in SwiftData; API keys belong in Keychain only.

**Goal:** Let the iPhone app add and remove BYOK provider profiles from Settings while persisting profile metadata separately from secrets.

**Architecture:** Add a `ProviderProfileRepository` over `ModelContext` and `KeychainStore`. Store preset, URL, model, and enabled state in `ProviderProfileRecord`; store the API key under a deterministic per-profile Keychain account. Add a SwiftUI Settings screen that lists profiles and presents a form for all required presets plus Custom.

**Tech Stack:** Swift 6, SwiftData, Security Keychain, SwiftUI, Swift Testing

---

### Task 1: Persist profile metadata and Keychain secrets separately

**Files:**
- Create: `DiaryCompanionCore/Tests/DiaryCompanionCoreTests/ProviderProfileRepositoryTests.swift`
- Create: `DiaryCompanionCore/Sources/DiaryCompanionCore/Persistence/ProviderProfileRepository.swift`

**Step 1: Write failing repository tests**

Cover:
- Save and fetch a profile.
- Load its API key from Keychain.
- Update metadata and rotate the API key without creating a duplicate profile.
- Delete both metadata and secret.

**Step 2: Run focused tests and verify failure**

Run: `swift test --package-path DiaryCompanionCore --filter ProviderProfileRepositoryTests`

Expected: compilation failure because `ProviderProfileRepository` does not exist.

**Step 3: Implement the repository**

Add profile conversion, deterministic Keychain accounts, upsert, fetch, key load, and delete operations.

**Step 4: Run focused tests**

Run: `swift test --package-path DiaryCompanionCore --filter ProviderProfileRepositoryTests`

Expected: pass.

### Task 2: Replace the Settings placeholder with a provider editor

**Files:**
- Modify: `DiaryCompanion/RootTabView.swift`
- Create: `DiaryCompanion/ProviderSettingsView.swift`

**Step 1: Add a provider list**

Use `@Query` for `ProviderProfileRecord`, show configured providers, and expose an add button.

**Step 2: Add the profile form**

Include provider preset, display name, Base URL, model name, API key, enabled state, validation feedback, save, and cancel.

**Step 3: Add deletion**

Delete metadata and its Keychain secret from the list swipe action.

### Task 3: Verify package and simulator behavior

**Step 1: Run package tests**

Run: `swift test --package-path DiaryCompanionCore`

Expected: all tests pass.

**Step 2: Build, install, and launch**

Run:
- `xcodebuild -project DiaryCompanion.xcodeproj -scheme DiaryCompanion -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath DerivedData build`
- `xcrun simctl install booted DerivedData/Build/Products/Debug-iphonesimulator/DiaryCompanion.app`
- `xcrun simctl launch --terminate-running-process booted com.liangbowenbill.DiaryCompanion`

Expected: app launches and Settings can present the provider form.
