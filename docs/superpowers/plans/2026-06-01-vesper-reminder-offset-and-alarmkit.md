# Vesper Reminder Offset and AlarmKit Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Separate event times from notification times and add explicit, iOS 26-only real alarms through AlarmKit.

**Architecture:** Keep recurrence expansion and persistence in `DiaryCompanionCore`, where macOS unit tests can exercise the behavior. Add an `AlarmClient` protocol and a core `AlarmOccurrenceFactory`; place the production AlarmKit adapter in the iOS app target behind `@available(iOS 26.0, *)`. Notifications and alarms both schedule fixed concrete occurrences derived from the event recurrence, preserving biweekly phase correctly.

**Tech Stack:** Swift 6, SwiftData, UserNotifications, EventKit, AlarmKit, SwiftUI, Swift Testing, Xcode iPhone simulator.

---

## File Map

- Modify `DiaryCompanionCore/Sources/DiaryCompanionCore/Reminders/ReminderProposal.swift`: add lead-time and alarm fields plus validation.
- Modify `DiaryCompanionCore/Sources/DiaryCompanionCore/Reminders/ReminderProposalEnvelopeParser.swift`: decode optional backward-compatible output fields.
- Modify `DiaryCompanionCore/Sources/DiaryCompanionCore/Reminders/ReminderAssistantPrompt.swift`: teach the model notification-versus-alarm rules.
- Modify `DiaryCompanionCore/Sources/DiaryCompanionCore/Notifications/ReminderRequestFactory.swift`: subtract notification lead time after recurrence expansion.
- Create `DiaryCompanionCore/Sources/DiaryCompanionCore/Alarms/AlarmClient.swift`: core alarm boundary, errors, occurrence factory, unavailable client.
- Create `DiaryCompanion/AlarmKitAlarmClient.swift`: iOS 26 AlarmKit production adapter using fixed schedules.
- Modify `DiaryCompanionCore/Sources/DiaryCompanionCore/Persistence/PersistedModels.swift`: store output configuration, results, and identifiers.
- Modify `DiaryCompanionCore/Sources/DiaryCompanionCore/Persistence/DiaryRepository.swift`: map new proposal and execution fields.
- Modify `DiaryCompanionCore/Sources/DiaryCompanionCore/Reminders/ReminderCleanupJournal.swift`: retain alarm identifiers for recovery.
- Modify `DiaryCompanionCore/Sources/DiaryCompanionCore/Reminders/ReminderSchedulingCoordinator.swift`: schedule, persist, cancel, and compensate alarms.
- Modify `DiaryCompanion/ReminderProposalCard.swift`: show event time, notification time, alarm state, and alarm time.
- Modify `DiaryCompanion/ReminderProposalEditorView.swift`: edit notification and alarm lead times.
- Modify `DiaryCompanion/VesperLocalization.swift`: bilingual labels and alarm errors.
- Modify `DiaryCompanion/ChatView.swift`, `DiaryCompanion/RootTabView.swift`, and `DiaryCompanion.xcodeproj/project.pbxproj`: inject the production alarm client.

### Task 1: Proposal Model And Assistant Envelope

**Files:**
- Modify: `DiaryCompanionCore/Sources/DiaryCompanionCore/Reminders/ReminderProposal.swift`
- Modify: `DiaryCompanionCore/Sources/DiaryCompanionCore/Reminders/ReminderProposalEnvelopeParser.swift`
- Modify: `DiaryCompanionCore/Sources/DiaryCompanionCore/Reminders/ReminderAssistantPrompt.swift`
- Test: `DiaryCompanionCore/Tests/DiaryCompanionCoreTests/ReminderProposalTests.swift`
- Test: `DiaryCompanionCore/Tests/DiaryCompanionCoreTests/ReminderProposalEnvelopeParserTests.swift`
- Test: `DiaryCompanionCore/Tests/DiaryCompanionCoreTests/ReminderAssistantPromptTests.swift`

- [ ] **Step 1: Write failing proposal validation tests**

Add tests that construct proposals with `notificationLeadMinutes: -1`, `alarmLeadMinutes: 10_081`, and `alarmEnabled: false`. Expect invalid lead times only for enabled outputs.

```swift
@Test func rejectsNegativeEnabledNotificationLeadTime() {
    var proposal = validProposal()
    proposal.notificationLeadMinutes = -1
    #expect(throws: ReminderProposalValidationError.invalidNotificationLeadMinutes) {
        try proposal.validate()
    }
}

@Test func permitsDormantAlarmLeadTimeWhileAlarmIsDisabled() throws {
    var proposal = validProposal()
    proposal.alarmEnabled = false
    proposal.alarmLeadMinutes = 10_081
    try proposal.validate()
}
```

- [ ] **Step 2: Run focused tests and verify RED**

Run:

```bash
swift test --package-path DiaryCompanionCore --filter LeadTime
```

Expected: compile failure because the new fields and validation cases do not exist.

- [ ] **Step 3: Add proposal fields and validation**

Add fields with backward-compatible initializer defaults:

```swift
public var notificationLeadMinutes: Int
public var alarmEnabled: Bool
public var alarmLeadMinutes: Int
```

Validate enabled lead times against `0...10_080`. Add bilingual validation descriptions.

- [ ] **Step 4: Add failing parser and prompt tests**

Verify that explicit JSON maps `notificationLeadMinutes`, `alarmEnabled`, and `alarmLeadMinutes`; legacy JSON defaults to `0`, `false`, `0`; and the prompt states that alarms are enabled only for explicit `闹钟` or `alarm` requests.

- [ ] **Step 5: Implement DTO defaults and prompt schema**

Use optional DTO fields:

```swift
var notificationLeadMinutes: Int?
var alarmEnabled: Bool?
var alarmLeadMinutes: Int?
```

Map with `?? 0`, `?? false`, and `?? 0`. Extend the JSON schema and natural-language rules.

- [ ] **Step 6: Run focused tests and commit**

Run:

```bash
swift test --package-path DiaryCompanionCore --filter ReminderProposal
swift test --package-path DiaryCompanionCore --filter ReminderAssistantPrompt
```

Expected: PASS.

Commit:

```bash
git add DiaryCompanionCore
git commit -m "feat: model reminder lead times and alarm intent"
```

### Task 2: Notification Lead-Time Scheduling

**Files:**
- Modify: `DiaryCompanionCore/Sources/DiaryCompanionCore/Notifications/ReminderRequestFactory.swift`
- Test: `DiaryCompanionCore/Tests/DiaryCompanionCoreTests/ReminderRequestFactoryTests.swift`

- [ ] **Step 1: Write the failing acceptance test**

```swift
@Test func schedulesBiweeklySundayNotificationThirtyMinutesBeforeEvent() throws {
    let requests = try ReminderRequestFactory(calendar: utcCalendar).makeRequests(
        reminderID: reminderID,
        proposal: makeProposal(
            start: date(2026, 6, 7, 15),
            recurrence: .weekly(interval: 2, weekdays: [.sunday], end: nil),
            notificationLeadMinutes: 30
        ),
        windowStart: date(2026, 6, 1),
        windowDays: 30
    )

    #expect(try requests.map(fireDate) == [
        date(2026, 6, 7, 14, 30),
        date(2026, 6, 21, 14, 30),
    ])
}
```

- [ ] **Step 2: Run the test and verify RED**

Run:

```bash
swift test --package-path DiaryCompanionCore --filter schedulesBiweeklySundayNotificationThirtyMinutesBeforeEvent
```

Expected: FAIL because requests still fire at `15:00`.

- [ ] **Step 3: Subtract lead time after recurrence expansion**

In `ReminderRequestFactory.makeRequests`, map event occurrences to fire dates:

```swift
let fireDate = calendar.date(
    byAdding: .minute,
    value: -proposal.notificationLeadMinutes,
    to: occurrence
)!
```

Filter fire dates before `windowStart`; keep identifiers based on the fire date.

- [ ] **Step 4: Verify focused and factory tests, then commit**

Run:

```bash
swift test --package-path DiaryCompanionCore --filter ReminderRequestFactory
```

Expected: PASS.

Commit:

```bash
git add DiaryCompanionCore
git commit -m "feat: schedule notifications before event start"
```

### Task 3: Alarm Boundary And Fixed Occurrence Factory

**Files:**
- Create: `DiaryCompanionCore/Sources/DiaryCompanionCore/Alarms/AlarmClient.swift`
- Test: `DiaryCompanionCore/Tests/DiaryCompanionCoreTests/AlarmOccurrenceFactoryTests.swift`

- [ ] **Step 1: Write failing alarm occurrence tests**

Cover:

```swift
@Test func expandsBiweeklySundayAlarmThirtyMinutesBeforeEvent() throws {
    let dates = try AlarmOccurrenceFactory(calendar: utcCalendar).dates(
        proposal: makeProposal(
            start: date(2026, 6, 7, 15),
            recurrence: .weekly(interval: 2, weekdays: [.sunday], end: nil),
            alarmEnabled: true,
            alarmLeadMinutes: 30
        ),
        windowStart: date(2026, 6, 1),
        windowDays: 30
    )
    #expect(dates == [
        date(2026, 6, 7, 14, 30),
        date(2026, 6, 21, 14, 30),
    ])
}
```

Also test disabled alarms return `[]` and past resolved alarm dates are skipped.

- [ ] **Step 2: Run the test and verify RED**

Run:

```bash
swift test --package-path DiaryCompanionCore --filter AlarmOccurrenceFactory
```

Expected: compile failure because the factory does not exist.

- [ ] **Step 3: Implement the core boundary**

Define:

```swift
public protocol AlarmClient: AnyObject {
    func requestAuthorization() async throws -> Bool
    func schedule(reminderID: UUID, proposal: ReminderProposal, windowStart: Date) async throws -> [String]
    func remove(ids: [String]) throws
}

public enum AlarmClientError: Error, Equatable, Sendable {
    case alarmRequiresIOS26
    case authorizationDenied
}
```

Implement `AlarmOccurrenceFactory` with concrete event recurrence expansion followed by `alarmLeadMinutes` subtraction. Extract shared recurrence expansion from `ReminderRequestFactory` into a focused internal helper so notification and alarm scheduling use identical recurrence phase logic.

- [ ] **Step 4: Run tests and commit**

Run:

```bash
swift test --package-path DiaryCompanionCore --filter AlarmOccurrenceFactory
swift test --package-path DiaryCompanionCore --filter ReminderRequestFactory
```

Expected: PASS.

Commit:

```bash
git add DiaryCompanionCore
git commit -m "feat: add fixed alarm occurrence scheduling"
```

### Task 4: Persist And Coordinate Alarm Outputs

**Files:**
- Modify: `DiaryCompanionCore/Sources/DiaryCompanionCore/Persistence/PersistedModels.swift`
- Modify: `DiaryCompanionCore/Sources/DiaryCompanionCore/Persistence/DiaryRepository.swift`
- Modify: `DiaryCompanionCore/Sources/DiaryCompanionCore/Reminders/ReminderCleanupJournal.swift`
- Modify: `DiaryCompanionCore/Sources/DiaryCompanionCore/Reminders/ReminderSchedulingCoordinator.swift`
- Test: `DiaryCompanionCore/Tests/DiaryCompanionCoreTests/DiaryRepositoryTests.swift`
- Test: `DiaryCompanionCore/Tests/DiaryCompanionCoreTests/ReminderCleanupJournalTests.swift`
- Test: `DiaryCompanionCore/Tests/DiaryCompanionCoreTests/ReminderSchedulingCoordinatorTests.swift`

- [ ] **Step 1: Write failing persistence round-trip tests**

Persist a proposal with a 30-minute notification lead and enabled 30-minute alarm lead. Expect reconstructed proposals and cleanup journals to preserve all fields and alarm identifiers.

- [ ] **Step 2: Write failing coordinator tests**

Use an `AlarmClientSpy` and verify:

- Alarm authorization and scheduling happen only when `alarmEnabled`.
- Confirmation persists alarm result and IDs.
- Cancellation removes alarm IDs.
- Compensation removes alarm IDs after persistence failure.
- `alarmRequiresIOS26` is surfaced rather than replaced with notification scheduling.

- [ ] **Step 3: Run tests and verify RED**

Run:

```bash
swift test --package-path DiaryCompanionCore --filter ReminderSchedulingCoordinator
swift test --package-path DiaryCompanionCore --filter DiaryRepository
swift test --package-path DiaryCompanionCore --filter ReminderCleanupJournal
```

Expected: compile failures because alarm persistence fields and coordinator dependencies do not exist.

- [ ] **Step 4: Extend persisted records and repository mappings**

Add:

```swift
public var notificationLeadMinutes: Int = 0
public var alarmEnabled: Bool = false
public var alarmLeadMinutes: Int = 0
public var alarmResult: String = ReminderExecutionResult.notRequested.rawValue
public var alarmIdentifiers: [String] = []
```

Update repository creation, reconstruction, proposal editing, execution persistence, reset, and legacy migration defaults.

- [ ] **Step 5: Extend cleanup journal and coordinator**

Add `alarmIdentifiers` to journal entries. Inject `AlarmClient` into the coordinator. Schedule alarms after notifications and before calendar creation. Include alarm IDs in edit, cancel, recovery, and compensation cleanup.

- [ ] **Step 6: Run focused tests and commit**

Run:

```bash
swift test --package-path DiaryCompanionCore --filter ReminderSchedulingCoordinator
swift test --package-path DiaryCompanionCore --filter DiaryRepository
swift test --package-path DiaryCompanionCore --filter ReminderCleanupJournal
```

Expected: PASS.

Commit:

```bash
git add DiaryCompanionCore
git commit -m "feat: persist and coordinate alarm outputs"
```

### Task 5: AlarmKit iOS Adapter

**Files:**
- Create: `DiaryCompanion/AlarmKitAlarmClient.swift`
- Modify: `DiaryCompanion.xcodeproj/project.pbxproj`
- Test: build verification with `xcodebuild`

- [ ] **Step 1: Add the production adapter**

Use guarded imports and availability:

```swift
#if canImport(AlarmKit)
import AlarmKit
import SwiftUI

@available(iOS 26.0, *)
final class AlarmKitAlarmClient: AlarmClient {
    private let manager = AlarmManager.shared
    // requestAuthorization(), schedule fixed dates, remove UUID ids
}
#endif
```

Each concrete occurrence uses:

```swift
let configuration = AlarmManager.AlarmConfiguration<VesperAlarmMetadata>.alarm(
    schedule: .fixed(fireDate),
    attributes: AlarmAttributes(
        presentation: AlarmPresentation(
            alert: .init(title: LocalizedStringResource(stringLiteral: proposal.title))
        ),
        metadata: VesperAlarmMetadata(reminderID: reminderID),
        tintColor: .accentColor
    )
)
```

Use deterministic UUID identifiers derived from reminder ID and fire date so retries are idempotent.

- [ ] **Step 2: Add an unavailable fallback**

Construct `UnavailableAlarmClient()` on iOS versions earlier than 26. It throws `AlarmClientError.alarmRequiresIOS26` only when an alarm is requested.

- [ ] **Step 3: Build and commit**

Run:

```bash
xcodebuild -project DiaryCompanion.xcodeproj \
  -scheme DiaryCompanion \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  build
```

Expected: `** BUILD SUCCEEDED **`.

Commit:

```bash
git add DiaryCompanion DiaryCompanion.xcodeproj
git commit -m "feat: schedule real alarms with AlarmKit"
```

### Task 6: Card And Editor Controls

**Files:**
- Modify: `DiaryCompanion/ReminderProposalCard.swift`
- Modify: `DiaryCompanion/ReminderProposalEditorView.swift`
- Modify: `DiaryCompanion/VesperLocalization.swift`
- Modify: `DiaryCompanion/ChatView.swift`
- Modify: `DiaryCompanion/RootTabView.swift`

- [ ] **Step 1: Add localized labels**

Add bilingual strings for event time, notification time, alarm, alarm time, lead-time summaries, iOS 26 requirement, and alarm authorization failure.

- [ ] **Step 2: Show separate card rows**

Replace the ambiguous reminder-time row with event time. Add notification and alarm rows:

```swift
detailRow(title: strings.eventTime, value: eventTimeText, systemImage: "calendar")
detailRow(title: strings.notificationTime, value: notificationTimeText, systemImage: "bell")
detailRow(title: strings.alarm, value: reminder.alarmEnabled ? strings.on : strings.off, systemImage: "alarm")
```

When alarms are enabled, add a separate alarm-time row.

- [ ] **Step 3: Extend editor draft and controls**

Add toggles and steppers:

```swift
Toggle(strings.soundAndVibration, isOn: $draft.notificationEnabled)
if draft.notificationEnabled {
    Stepper(strings.minutesBefore(draft.notificationLeadMinutes), value: $draft.notificationLeadMinutes, in: 0...10_080, step: 5)
}
Toggle(strings.realAlarm, isOn: $draft.alarmEnabled)
if draft.alarmEnabled {
    Stepper(strings.minutesBefore(draft.alarmLeadMinutes), value: $draft.alarmLeadMinutes, in: 0...10_080, step: 5)
    Text(strings.realAlarmRequiresIOS26)
}
```

- [ ] **Step 4: Inject alarm client and build**

Pass an AlarmKit adapter on iOS 26 and an unavailable adapter otherwise when constructing `ReminderSchedulingCoordinator`.

Run:

```bash
xcodebuild -project DiaryCompanion.xcodeproj \
  -scheme DiaryCompanion \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  build
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 5: Commit**

```bash
git add DiaryCompanion DiaryCompanion.xcodeproj
git commit -m "feat: edit notification and alarm times in reminder cards"
```

### Task 7: Full Verification And Human-Style Acceptance

**Files:**
- Test: `DiaryCompanionCore/Tests/DiaryCompanionCoreTests/*`
- Verify: iPhone 17 Pro simulator

- [ ] **Step 1: Run full automated verification**

```bash
git diff --check
swift test --package-path DiaryCompanionCore
xcodebuild -project DiaryCompanion.xcodeproj \
  -scheme DiaryCompanion \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  build
```

Expected: no whitespace errors, all Swift tests pass, and `** BUILD SUCCEEDED **`.

- [ ] **Step 2: Run the reminder-only acceptance case**

In chat, submit:

```text
Starting next Sunday, I plan to meet my girlfriend every two weeks on Sunday at 3:00 PM. Remind me 30 minutes in advance.
```

Answer the duration follow-up with:

```text
2 hours.
```

Verify the card shows event `15:00`, notification `14:30`, alarm off, every two weeks on Sunday, duration `120 min`, and calendar on. Confirm and verify calendar creation.

- [ ] **Step 3: Run the explicit-alarm acceptance case**

Submit:

```text
Starting next Sunday, set an alarm and remind me 30 minutes before I meet my girlfriend every two weeks on Sunday at 3:00 PM.
```

Answer `2 hours.` Verify the card shows notification and alarm both at `14:30`. Confirm on the iOS 26.5 simulator and inspect scheduled output state.

- [ ] **Step 4: Verify the old-system fallback with unit coverage**

Use `UnavailableAlarmClient` in a coordinator unit test. Confirm explicit alarms fail with the bilingual iOS 26 requirement and no fallback notification is silently added.

- [ ] **Step 5: Commit any verification fixture updates**

```bash
git add DiaryCompanionCore DiaryCompanion
git commit -m "test: cover reminder offsets and explicit alarms"
```
