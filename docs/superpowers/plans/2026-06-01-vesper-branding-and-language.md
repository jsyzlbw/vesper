# Vesper Branding and App Language Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rename the user-facing app to Vesper, install a twilight-orbit iOS icon, and add immediate Simplified Chinese or English UI switching with system-language fallback and adaptive AI reply language.

**Architecture:** Add a focused app-local localization module for SwiftUI views and a small core localization module for errors and AI reply-language selection. Persist the user's app-language choice with `AppStorage`, inject the resolved language through SwiftUI environment, and keep internal target names and bundle identifier unchanged. Add a universal 1024px AppIcon asset and configure Xcode to consume it.

**Tech Stack:** SwiftUI, SwiftData, Swift Package Manager tests, Xcode asset catalogs, iOS Simulator, built-in image generation.

---

### Task 1: Add Core Language Rules

**Files:**
- Create: `DiaryCompanionCore/Sources/DiaryCompanionCore/Localization/VesperLanguage.swift`
- Test: `DiaryCompanionCore/Tests/DiaryCompanionCoreTests/VesperLanguageTests.swift`

- [ ] **Step 1: Write failing tests for explicit choices, system fallback, Chinese detection, and AI reply instruction**

```swift
import Testing
@testable import DiaryCompanionCore

@Test func followsSimplifiedChineseSystemLanguage() {
    #expect(VesperLanguage.followSystem.resolve(preferredLanguages: ["zh-Hans-CN"]) == .simplifiedChinese)
}

@Test func traditionalChineseFallsBackToEnglish() {
    #expect(VesperLanguage.followSystem.resolve(preferredLanguages: ["zh-Hant-TW"]) == .english)
}

@Test func chineseMessageOverridesEnglishAIReplyLanguage() {
    #expect(VesperAIReplyLanguage.instruction(appLanguage: .english, latestUserText: "明天提醒我喝水").contains("简体中文"))
}
```

- [ ] **Step 2: Run focused tests and verify failure**

Run: `swift test --package-path DiaryCompanionCore --filter VesperLanguage`

Expected: FAIL because `VesperLanguage` does not exist.

- [ ] **Step 3: Implement language resolution and AI reply-language instruction**

```swift
public enum VesperSupportedLanguage: String, Codable, Sendable {
    case simplifiedChinese
    case english
}

public enum VesperLanguage: String, Codable, CaseIterable, Sendable {
    case followSystem
    case simplifiedChinese
    case english

    public func resolve(preferredLanguages: [String]) -> VesperSupportedLanguage {
        switch self {
        case .simplifiedChinese: .simplifiedChinese
        case .english: .english
        case .followSystem:
            preferredLanguages.first?.lowercased().hasPrefix("zh-hans") == true
                ? .simplifiedChinese
                : .english
        }
    }
}

public enum VesperAIReplyLanguage {
    public static func containsChinese(_ text: String) -> Bool {
        text.unicodeScalars.contains { scalar in
            (0x4E00...0x9FFF).contains(scalar.value)
        }
    }
}
```

- [ ] **Step 4: Run focused tests and verify pass**

Run: `swift test --package-path DiaryCompanionCore --filter VesperLanguage`

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add DiaryCompanionCore/Sources/DiaryCompanionCore/Localization/VesperLanguage.swift \
  DiaryCompanionCore/Tests/DiaryCompanionCoreTests/VesperLanguageTests.swift
git commit -m "feat: add Vesper language rules"
```

### Task 2: Add App Localization Context and Strings

**Files:**
- Create: `DiaryCompanion/VesperLocalization.swift`
- Modify: `DiaryCompanion/DiaryCompanionApp.swift`
- Modify: `DiaryCompanion.xcodeproj/project.pbxproj`

- [ ] **Step 1: Add `VesperLocalization.swift` with environment context and typed bilingual strings**

Include:

```swift
struct VesperLocalizationContext {
    let language: VesperSupportedLanguage
    var locale: Locale {
        Locale(identifier: language == .simplifiedChinese ? "zh_Hans_CN" : "en_US")
    }
}

private struct VesperLocalizationContextKey: EnvironmentKey {
    static let defaultValue = VesperLocalizationContext(language: .english)
}
```

Add `VesperStrings` accessors for all current app-visible strings, including interpolation helpers such as duration, interval, total occurrences, connection success, endpoint footer, and localized weekday titles.

- [ ] **Step 2: Inject language setting from the app root**

Use:

```swift
@AppStorage("vesper.appLanguage")
private var appLanguageRawValue = VesperLanguage.followSystem.rawValue
```

Resolve against `Locale.preferredLanguages`, inject the localization context, and set `.environment(\.locale, context.locale)`.

- [ ] **Step 3: Add new Swift file to Xcode project**

Add the file reference, source build file, group membership, and Sources build phase membership in `DiaryCompanion.xcodeproj/project.pbxproj`.

- [ ] **Step 4: Build to verify compile**

Run:

```bash
xcodebuild -project DiaryCompanion.xcodeproj \
  -scheme DiaryCompanion \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  build
```

Expected: BUILD SUCCEEDED.

- [ ] **Step 5: Commit**

```bash
git add DiaryCompanion/VesperLocalization.swift DiaryCompanion/DiaryCompanionApp.swift \
  DiaryCompanion.xcodeproj/project.pbxproj
git commit -m "feat: add Vesper app localization context"
```

### Task 3: Localize Current SwiftUI Screens

**Files:**
- Modify: `DiaryCompanion/RootTabView.swift`
- Modify: `DiaryCompanion/ChatView.swift`
- Modify: `DiaryCompanion/ProviderSettingsView.swift`
- Modify: `DiaryCompanion/ReminderProposalCard.swift`
- Modify: `DiaryCompanion/ReminderProposalEditorView.swift`

- [ ] **Step 1: Read localization context in each screen**

Add:

```swift
@Environment(\.vesperLocalization) private var localization
```

Use `localization.strings` for every visible label, title, message, button, placeholder, and empty state.

- [ ] **Step 2: Add language picker to Settings**

Store the persisted raw value with:

```swift
@AppStorage("vesper.appLanguage")
private var appLanguageRawValue = VesperLanguage.followSystem.rawValue
```

Render a Picker between provider and permissions sections. Present localized labels for `Follow System`, `简体中文`, and `English`.

- [ ] **Step 3: Format reminder dates using selected locale**

Pass `localization.locale` to `Date.formatted` calls in `ReminderProposalCard`.

- [ ] **Step 4: Update AI system prompt**

Build the assistant prose instruction from:

```swift
VesperAIReplyLanguage.instruction(
    appLanguage: localization.language,
    latestUserText: records.last(where: { $0.role == ChatRole.user.rawValue })?.content ?? ""
)
```

Keep the reminder envelope schema unchanged.

- [ ] **Step 5: Build to verify all SwiftUI screens compile**

Run:

```bash
xcodebuild -project DiaryCompanion.xcodeproj \
  -scheme DiaryCompanion \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  build
```

Expected: BUILD SUCCEEDED.

- [ ] **Step 6: Commit**

```bash
git add DiaryCompanion
git commit -m "feat: localize Vesper interface"
```

### Task 4: Localize Core Validation Errors

**Files:**
- Modify: `DiaryCompanionCore/Sources/DiaryCompanionCore/Localization/VesperLanguage.swift`
- Modify: `DiaryCompanionCore/Sources/DiaryCompanionCore/Reminders/ReminderProposal.swift`
- Test: `DiaryCompanionCore/Tests/DiaryCompanionCoreTests/VesperLanguageTests.swift`

- [ ] **Step 1: Add failing tests for localized validation messages**

```swift
@Test func localizesReminderValidationError() {
    #expect(
        ReminderProposalValidationError.emptyTitle
            .localizedDescription(language: .english) == "Reminder title cannot be empty."
    )
}
```

- [ ] **Step 2: Run focused test and verify failure**

Run: `swift test --package-path DiaryCompanionCore --filter localizesReminderValidationError`

Expected: FAIL because localized description helper does not exist.

- [ ] **Step 3: Add localized error helper and use it from SwiftUI error presentation**

Keep `LocalizedError.errorDescription` as a system-language fallback. Add:

```swift
public func localizedDescription(
    language: VesperSupportedLanguage
) -> String
```

Translate every `ReminderProposalValidationError` case.

- [ ] **Step 4: Run full core tests**

Run: `swift test --package-path DiaryCompanionCore`

Expected: all tests pass.

- [ ] **Step 5: Commit**

```bash
git add DiaryCompanionCore DiaryCompanion
git commit -m "feat: localize reminder validation errors"
```

### Task 5: Generate and Install Vesper App Icon

**Files:**
- Create: `DiaryCompanion/Assets.xcassets/Contents.json`
- Create: `DiaryCompanion/Assets.xcassets/AppIcon.appiconset/Contents.json`
- Create: `DiaryCompanion/Assets.xcassets/AppIcon.appiconset/Vesper-AppIcon-1024.png`
- Modify: `DiaryCompanion.xcodeproj/project.pbxproj`

- [ ] **Step 1: Generate icon source using built-in image generation**

Prompt:

```text
Use case: logo-brand
Asset type: iOS app icon source, square 1024x1024
Primary request: Create a premium minimalist app icon for Vesper, a quiet private AI companion.
Scene/backdrop: deep twilight navy to muted blue background, subtle depth, no transparency.
Subject: one thin restrained luminous circular orbit centered in the icon, with one small warm amber light point on the upper-right arc. The orbit suggests time, daily rhythm, memory, and a quiet companion keeping watch.
Composition: centered, generous padding for iOS rounded-square masking, legible at 60px.
Style: calm, refined, editorial, premium native iOS; very subtle glow only.
Avoid: text, letters, chat bubbles, robot faces, notebooks, calendars, clocks with hands, stars scattered across the background, busy gradients, excessive gloss, watermark, mockup frame, rounded-corner mask baked into the bitmap.
```

- [ ] **Step 2: Inspect the generated icon and copy the selected PNG into the asset catalog**

Ensure the output is exactly square and readable at small size.

- [ ] **Step 3: Add asset catalog metadata**

Use a universal iOS 1024px app icon entry:

```json
{
  "images" : [
    {
      "filename" : "Vesper-AppIcon-1024.png",
      "idiom" : "universal",
      "platform" : "ios",
      "size" : "1024x1024"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
```

- [ ] **Step 4: Configure display name and asset catalog**

Set:

```text
ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
INFOPLIST_KEY_CFBundleDisplayName = Vesper;
```

for Debug and Release in `DiaryCompanion.xcodeproj/project.pbxproj`.

- [ ] **Step 5: Build and inspect compiled app metadata**

Run:

```bash
xcodebuild -project DiaryCompanion.xcodeproj \
  -scheme DiaryCompanion \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  build
plutil -p ~/Library/Developer/Xcode/DerivedData/DiaryCompanion-*/Build/Products/Debug-iphonesimulator/DiaryCompanion.app/Info.plist
```

Expected: BUILD SUCCEEDED and `CFBundleDisplayName` is `Vesper`.

- [ ] **Step 6: Commit**

```bash
git add DiaryCompanion/Assets.xcassets DiaryCompanion.xcodeproj/project.pbxproj
git commit -m "feat: add Vesper app icon and display name"
```

### Task 6: Simulator Acceptance Test

**Files:**
- No source changes expected.

- [ ] **Step 1: Run full verification**

```bash
swift test --package-path DiaryCompanionCore
xcodebuild -project DiaryCompanion.xcodeproj \
  -scheme DiaryCompanion \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  build
```

Expected: all core tests pass and BUILD SUCCEEDED.

- [ ] **Step 2: Install and launch**

```bash
xcrun simctl install booted \
  ~/Library/Developer/Xcode/DerivedData/DiaryCompanion-*/Build/Products/Debug-iphonesimulator/DiaryCompanion.app
xcrun simctl launch --terminate-running-process booted com.liangbowenbill.DiaryCompanion
```

- [ ] **Step 3: Simulate language switching**

Verify:

- Settings shows App Language.
- Simplified Chinese updates the current settings screen and all tabs immediately.
- English updates the current settings screen and all tabs immediately.
- Follow System resolves correctly for the simulator language.

- [ ] **Step 4: Simulate AI reply language**

In English UI:

- Send an English message and confirm the assistant responds in English.
- Send a Chinese message and confirm the assistant responds in Chinese.

- [ ] **Step 5: Verify icon on simulator home screen**

Return to the simulator home screen and confirm the Vesper icon and display name are visible.

- [ ] **Step 6: Check clean worktree**

Run: `git status --short`

Expected: no output.
