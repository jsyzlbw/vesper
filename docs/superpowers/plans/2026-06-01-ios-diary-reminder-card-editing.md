# Reminder Card Editing Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let users tap reminder-card rows to edit an AI reminder proposal before explicitly confirming notification and calendar creation.

**Architecture:** Add a small Core editor-support type for deterministic defaults and human-readable recurrence summaries. Add a SwiftUI sheet that owns draft fields, produces a validated `ReminderProposal`, and delegates persistence to `ChatView`; reuse the existing coordinator and automatic calendar resolver so edits remain confirmation-only.

**Tech Stack:** Swift 6, SwiftUI, SwiftData, EventKit, Swift Testing, Xcode iOS Simulator.

---

### Task 1: Add deterministic editor support

**Files:**
- Create: `DiaryCompanionCore/Sources/DiaryCompanionCore/Reminders/ReminderProposalEditorSupport.swift`
- Create: `DiaryCompanionCore/Tests/DiaryCompanionCoreTests/ReminderProposalEditorSupportTests.swift`

- [ ] **Step 1: Write failing tests for scheduling defaults**

Cover these public APIs:

```swift
let preserved = ReminderProposalEditorSupport.preparedForEditing(
    proposal,
    now: date(2026, 6, 1, 10, 7),
    calendar: utcCalendar
)
#expect(preserved.searchWindow == proposal.searchWindow)

let automatic = ReminderProposalEditorSupport.preparedForEditing(
    proposalWithoutWindow,
    now: date(2026, 6, 1, 10, 7),
    calendar: utcCalendar
)
#expect(automatic.searchWindow == ReminderSearchWindow(
    start: date(2026, 6, 1, 10, 7),
    end: date(2026, 6, 2)
))

let fixed = ReminderProposalEditorSupport.preparedForEditing(
    fixedProposalWithoutStart,
    now: date(2026, 6, 1, 10, 7),
    calendar: utcCalendar
)
#expect(fixed.start == date(2026, 6, 1, 10, 15))
```

- [ ] **Step 2: Run the new test file and verify RED**

Run:

```bash
swift test --package-path DiaryCompanionCore --filter ReminderProposalEditorSupportTests
```

Expected: FAIL because `ReminderProposalEditorSupport` does not exist.

- [ ] **Step 3: Implement editor defaults and summaries**

Create:

```swift
public enum ReminderProposalEditorSupport {
    public static func preparedForEditing(
        _ proposal: ReminderProposal,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> ReminderProposal

    public static func recurrenceSummary(_ recurrence: ReminderRecurrenceRule) -> String
}
```

`preparedForEditing` preserves valid existing values. For missing automatic windows use
`now..<startOfTomorrow`; for missing fixed starts use the next 15-minute boundary.
`recurrenceSummary` returns concise Chinese summaries for every recurrence kind and optional
end condition.

- [ ] **Step 4: Run focused tests and verify GREEN**

Run:

```bash
swift test --package-path DiaryCompanionCore --filter ReminderProposalEditorSupportTests
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add DiaryCompanionCore/Sources/DiaryCompanionCore/Reminders/ReminderProposalEditorSupport.swift DiaryCompanionCore/Tests/DiaryCompanionCoreTests/ReminderProposalEditorSupportTests.swift
git commit -m "feat: add reminder proposal editor defaults"
```

### Task 2: Build the native reminder editor sheet

**Files:**
- Create: `DiaryCompanion/ReminderProposalEditorView.swift`
- Modify: `DiaryCompanion.xcodeproj/project.pbxproj`

- [ ] **Step 1: Add the SwiftUI editor**

Create `ReminderProposalEditorView` with:

```swift
struct ReminderProposalEditorView: View {
    let originalProposal: ReminderProposal
    let save: (ReminderProposal) async throws -> Void
}
```

The view must:

- initialize draft fields through `ReminderProposalEditorSupport.preparedForEditing`
- edit title, notes, scheduling mode, fixed start, automatic search window, recurrence,
  duration, notification toggle, and calendar toggle
- validate the constructed proposal before calling `save`
- remain presented and show an inline error if validation, automatic scheduling, or
  persistence fails
- dismiss only after successful save or explicit cancel

- [ ] **Step 2: Add the file to the Xcode target**

Add `ReminderProposalEditorView.swift` to the PBX file references, app group, and Sources build
phase using the next unused project IDs.

- [ ] **Step 3: Compile the app**

Run:

```bash
xcodebuild -project DiaryCompanion.xcodeproj -scheme DiaryCompanion -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

Expected: `BUILD SUCCEEDED`.

- [ ] **Step 4: Commit**

```bash
git add DiaryCompanion/ReminderProposalEditorView.swift DiaryCompanion.xcodeproj/project.pbxproj
git commit -m "feat: add reminder proposal editor sheet"
```

### Task 3: Make card rows explicit and tappable

**Files:**
- Modify: `DiaryCompanion/ReminderProposalCard.swift`
- Modify: `DiaryCompanion/ChatView.swift`

- [ ] **Step 1: Replace ambiguous detail labels**

Change the card to render tappable rows:

```swift
CardRow(title: "安排方式", value: schedulingModeText, systemImage: "calendar.badge.clock")
CardRow(title: "提醒时间", value: scheduleText, systemImage: "bell")
CardRow(title: "重复规则", value: ReminderProposalEditorSupport.recurrenceSummary(proposal.recurrence), systemImage: "arrow.trianglehead.2.clockwise")
CardRow(title: "事件持续时间", value: "\(reminder.durationMinutes) 分钟", systemImage: "hourglass")
CardRow(title: "系统通知", value: reminder.notificationEnabled ? "开启" : "关闭", systemImage: "bell.badge")
CardRow(title: "同步到日历", value: reminder.calendarEnabled ? "开启" : "关闭", systemImage: "calendar.badge.plus")
```

Rows and title/notes invoke an edit action only for `pendingConfirmation`.

- [ ] **Step 2: Present the editor from ChatView**

Extend card actions with `.edit`. In `ChatView`, store the selected `ReminderRecord`, reconstruct
its proposal through `DiaryRepository`, present `ReminderProposalEditorView`, resolve automatic
scheduling on save, and call:

```swift
try coordinator.edit(reminderID: reminder.id, proposal: resolvedProposal)
```

- [ ] **Step 3: Compile and visually verify**

Run:

```bash
xcodebuild -project DiaryCompanion.xcodeproj -scheme DiaryCompanion -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
xcrun simctl install booted ~/Library/Developer/Xcode/DerivedData/DiaryCompanion-*/Build/Products/Debug-iphonesimulator/DiaryCompanion.app
xcrun simctl launch booted com.liangbowenbill.DiaryCompanion
```

Expected:

- card shows explicit `提醒时间` and `事件持续时间`
- tapping an editable row opens the sheet
- save updates the card but does not create external resources
- `确认创建` remains the only creation action

- [ ] **Step 4: Commit**

```bash
git add DiaryCompanion/ReminderProposalCard.swift DiaryCompanion/ChatView.swift
git commit -m "feat: make reminder card rows editable"
```

### Task 4: Final verification

**Files:**
- Verify only

- [ ] **Step 1: Run whitespace verification**

```bash
git diff --check
```

Expected: no output.

- [ ] **Step 2: Run full Core suite**

```bash
swift test --package-path DiaryCompanionCore
```

Expected: all tests pass.

- [ ] **Step 3: Run simulator build**

```bash
xcodebuild -project DiaryCompanion.xcodeproj -scheme DiaryCompanion -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

Expected: `BUILD SUCCEEDED`.

- [ ] **Step 4: Check worktree**

```bash
git status --short
```

Expected: no output.
