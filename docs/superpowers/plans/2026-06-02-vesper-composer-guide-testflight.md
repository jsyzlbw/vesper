# Vesper Composer, In-App Guide, and TestFlight Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Polish Vesper's chat composer, embed the tester guide in Settings, and add a repeatable external TestFlight release workflow.

**Architecture:** Keep the UI changes app-local: `ChatView` owns keyboard focus and the warm card composer, while a new `VesperUserGuideView` owns offline guide presentation. Add explicit Xcode version settings and a shell release helper that supports diagnostic preflight, archive/export, and optional App Store Connect API-key upload.

**Tech Stack:** SwiftUI, Xcode build settings, `xcodebuild`, App Store Connect upload export.

---

### Task 1: Chat Composer Keyboard Behavior and Visual Polish

**Files:**
- Modify: `DiaryCompanion/ChatView.swift`

- [ ] **Step 1: Add focus state and deterministic keyboard dismissal**

Add `@FocusState private var isComposerFocused: Bool`, bind the text field with
`.focused($isComposerFocused)`, set `isComposerFocused = false` after sending,
and apply:

```swift
.scrollDismissesKeyboard(.interactively)
.simultaneousGesture(
    TapGesture().onEnded {
        isComposerFocused = false
    }
)
```

to the message scroll view.

- [ ] **Step 2: Replace the default composer with the selected warm card**

Use a rounded white surface, subtle border and shadow, multiline input, a small
natural-language label, a circular send button, and a keyboard toolbar:

```swift
.toolbar {
    ToolbarItemGroup(placement: .keyboard) {
        Spacer()
        Button(localization.strings.dismissKeyboard) {
            isComposerFocused = false
        }
    }
}
```

- [ ] **Step 3: Build for Simulator**

Run:

```bash
xcodebuild -project DiaryCompanion.xcodeproj -scheme DiaryCompanion \
  -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

Expected: `** BUILD SUCCEEDED **`

### Task 2: Offline In-App User Guide

**Files:**
- Create: `DiaryCompanion/VesperUserGuideView.swift`
- Modify: `DiaryCompanion/ProviderSettingsView.swift`
- Modify: `DiaryCompanion/VesperLocalization.swift`
- Modify: `DiaryCompanion.xcodeproj/project.pbxproj`

- [ ] **Step 1: Add localized guide navigation labels**

Add strings for `support`, `userGuide`, `dismissKeyboard`, and the reading-page
section titles.

- [ ] **Step 2: Build a native guide view**

Create `VesperUserGuideView` with a `List` of guide sections covering:
introduction, provider setup, reminders, real alarms, calendar and automatic
scheduling, language, permissions, limitations, and tester examples.

- [ ] **Step 3: Add the Settings entry**

Add a Settings `Section(localization.strings.support)` with:

```swift
NavigationLink {
    VesperUserGuideView()
} label: {
    Label(localization.strings.userGuide, systemImage: "book.closed")
}
```

- [ ] **Step 4: Add the source file to the Xcode target and build**

Run the Simulator build command from Task 1.

Expected: `** BUILD SUCCEEDED **`

### Task 3: TestFlight Release Workflow

**Files:**
- Create: `scripts/testflight.sh`
- Modify: `DiaryCompanion.xcodeproj/project.pbxproj`

- [ ] **Step 1: Add explicit app version settings**

Set both target configurations:

```text
MARKETING_VERSION = 0.1.0;
CURRENT_PROJECT_VERSION = 1;
```

- [ ] **Step 2: Add the release helper**

Create an executable script with:

```bash
./scripts/testflight.sh preflight
./scripts/testflight.sh archive
./scripts/testflight.sh upload
```

`preflight` checks Xcode, scheme visibility, bundle ID, version/build values,
code-signing identities, and App Store Connect API-key variables. `archive`
creates `artifacts/testflight/Vesper.xcarchive` and exports an App Store Connect
IPA. `upload` requires `ASC_API_KEY_ID`, `ASC_API_ISSUER_ID`, and
`ASC_API_PRIVATE_KEY_PATH`, then uses `xcrun altool`.

- [ ] **Step 3: Add the Chinese external TestFlight checklist**

Document Apple Developer Program enrollment, App Store Connect app-record
creation, external group setup, Beta App Review, script commands, build-number
increments, and the account-owner-only enrollment steps.

- [ ] **Step 4: Run preflight**

Run:

```bash
./scripts/testflight.sh preflight
```

Expected: a clear pass/fail report. Missing distribution enrollment or API key
must be reported as an actionable warning rather than an opaque command error.

### Task 4: Simulator Interaction Regression

**Files:**
- No production file changes

- [ ] **Step 1: Install and launch the Simulator app**

Build and use `xcrun simctl install` and `xcrun simctl launch`.

- [ ] **Step 2: Exercise the chat composer**

Verify input focus, multiline card appearance, keyboard toolbar dismiss button,
interactive scroll dismissal, background-tap dismissal, and send dismissal.

- [ ] **Step 3: Exercise the Settings guide**

Verify Settings shows the User Guide row and the native reading page renders.

### Task 5: Full Verification

**Files:**
- No production file changes

- [ ] **Step 1: Run core tests**

Run:

```bash
swift test --package-path DiaryCompanionCore
```

Expected: all tests pass.

- [ ] **Step 2: Run patch checks**

Run:

```bash
git diff --check
git status --short
```

Expected: no whitespace errors and only intended changes.

- [ ] **Step 3: Commit implementation**

Commit the completed feature with a scoped message.
