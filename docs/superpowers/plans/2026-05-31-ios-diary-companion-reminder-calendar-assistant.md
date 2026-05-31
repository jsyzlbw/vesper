# Reminder and Calendar Assistant Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a confirmation-first reminder assistant that parses AI proposals, supports complex recurrence, schedules local notifications, writes calendar events, finds free calendar slots, and renders durable chat cards.

**Architecture:** The AI emits a provider-neutral JSON envelope embedded in streamed text. App-owned domain types decode and validate the proposal before persistence or side effects. A coordinator independently schedules `UNUserNotificationCenter` notifications and EventKit calendar events after explicit user confirmation, preserving partial success.

**Tech Stack:** Swift 6, SwiftUI, SwiftData, UserNotifications, EventKit, Swift Testing

---

## File Map

- Create `DiaryCompanionCore/Sources/DiaryCompanionCore/Reminders/ReminderProposal.swift`: app-owned proposal, recurrence, status, and validation types.
- Create `DiaryCompanionCore/Sources/DiaryCompanionCore/Reminders/ReminderProposalEnvelopeParser.swift`: extract and decode AI JSON envelopes from assistant output.
- Modify `DiaryCompanionCore/Sources/DiaryCompanionCore/Persistence/PersistedModels.swift`: persist proposal and execution state.
- Modify `DiaryCompanionCore/Sources/DiaryCompanionCore/Persistence/DiaryRepository.swift`: create, fetch, update reminder proposals.
- Modify `DiaryCompanionCore/Sources/DiaryCompanionCore/Notifications/ReminderRequestFactory.swift`: create concrete notification requests from complex recurrence rules.
- Create `DiaryCompanionCore/Sources/DiaryCompanionCore/Reminders/ReminderSchedulingCoordinator.swift`: confirmation-only notification and calendar execution with partial results.
- Create `DiaryCompanionCore/Sources/DiaryCompanionCore/Calendar/CalendarAvailabilityService.swift`: deterministic free-slot selection.
- Create `DiaryCompanionCore/Sources/DiaryCompanionCore/Calendar/EventKitCalendarClient.swift`: EventKit boundary for visible calendar reads and event writes.
- Modify `DiaryCompanion/ChatView.swift`: include proposal instructions, parse completed assistant output, and render reminder cards.
- Create `DiaryCompanion/ReminderProposalCard.swift`: pending, executing, and result UI states with confirm/edit/cancel actions.
- Modify `DiaryCompanion/DiaryCompanionApp.swift`: request and expose notification and EventKit dependencies.

### Task 1: Reminder Proposal Domain

**Files:**
- Create: `DiaryCompanionCore/Sources/DiaryCompanionCore/Reminders/ReminderProposal.swift`
- Create: `DiaryCompanionCore/Tests/DiaryCompanionCoreTests/ReminderProposalTests.swift`

- [ ] **Step 1: Write failing validation tests**

Add tests that construct `ReminderProposal` values and assert:

```swift
@Test func acceptsBiweeklyMondayRule() throws {
    let proposal = ReminderProposal(
        title: "复习",
        notes: "",
        start: try #require(Calendar(identifier: .gregorian).date(
            from: DateComponents(year: 2026, month: 6, day: 1, hour: 19, minute: 30)
        )),
        durationMinutes: 60,
        recurrence: .weekly(interval: 2, weekdays: [.monday], end: nil),
        schedulingMode: .fixed,
        searchWindow: nil,
        notificationEnabled: true,
        calendarEnabled: true
    )
    try proposal.validate()
}

@Test func rejectsMissingStartForFixedProposal() {
    let proposal = ReminderProposal(
        title: "复习", notes: "", start: nil, durationMinutes: 60,
        recurrence: .once, schedulingMode: .fixed,
        searchWindow: nil,
        notificationEnabled: true, calendarEnabled: true
    )
    #expect(throws: ReminderProposalValidationError.missingStart) {
        try proposal.validate()
    }
}
```

Cover `.once`, `.daily(interval:end:)`, `.weekly(interval:weekdays:end:)`,
`.monthly(interval:day:end:)`, `.monthlyLastDay(interval:end:)`, and
`.yearly(interval:month:day:end:)`. Reject empty titles, durations outside
`1...1440`, zero intervals, and fixed proposals without a start.

- [ ] **Step 2: Run the focused tests and verify RED**

Run:

```bash
swift test --package-path DiaryCompanionCore --filter ReminderProposalTests
```

Expected: FAIL because `ReminderProposal` does not exist.

- [ ] **Step 3: Implement domain types and validation**

Create Codable, Equatable, Sendable types:

```swift
public enum ReminderWeekday: Int, Codable, CaseIterable, Sendable {
    case sunday = 1, monday, tuesday, wednesday, thursday, friday, saturday
}

public enum ReminderRecurrenceRule: Codable, Equatable, Sendable {
    case once
    case daily(interval: Int, end: ReminderRecurrenceEnd?)
    case weekly(interval: Int, weekdays: [ReminderWeekday], end: ReminderRecurrenceEnd?)
    case monthly(interval: Int, day: Int, end: ReminderRecurrenceEnd?)
    case monthlyLastDay(interval: Int, end: ReminderRecurrenceEnd?)
    case yearly(interval: Int, month: Int, day: Int, end: ReminderRecurrenceEnd?)
}

public enum ReminderSchedulingMode: String, Codable, Sendable {
    case fixed
    case findFreeTime
}

public enum ReminderRecurrenceEnd: Codable, Equatable, Sendable {
    case date(Date)
    case occurrenceCount(Int)
}

public struct ReminderSearchWindow: Codable, Equatable, Sendable {
    public var start: Date
    public var end: Date
}
```

Implement `ReminderProposal.validate()` with the constraints asserted above.
`ReminderProposal` includes `searchWindow: ReminderSearchWindow?`.
`findFreeTime` proposals require a valid search window whose end follows its
start. Recurrence occurrence counts must be positive.

- [ ] **Step 4: Run tests and verify GREEN**

Run:

```bash
swift test --package-path DiaryCompanionCore --filter ReminderProposalTests
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add DiaryCompanionCore/Sources/DiaryCompanionCore/Reminders DiaryCompanionCore/Tests/DiaryCompanionCoreTests/ReminderProposalTests.swift
git commit -m "feat: define reminder proposal rules"
```

### Task 2: AI Reminder Envelope Parser

**Files:**
- Create: `DiaryCompanionCore/Sources/DiaryCompanionCore/Reminders/ReminderProposalEnvelopeParser.swift`
- Create: `DiaryCompanionCore/Tests/DiaryCompanionCoreTests/ReminderProposalEnvelopeParserTests.swift`

- [ ] **Step 1: Write failing parser tests**

Use an envelope that remains provider-neutral:

```text
[[DIARY_REMINDER_PROPOSAL]]
{"title":"复习","notes":"","start":"2026-06-01T19:30:00+08:00","durationMinutes":60,"recurrence":{"kind":"weekly","interval":2,"weekdays":[2]},"schedulingMode":"fixed","searchWindow":null,"notificationEnabled":true,"calendarEnabled":true}
[[/DIARY_REMINDER_PROPOSAL]]
```

Assert that `ReminderProposalEnvelopeParser.parse(_:)` returns:

```swift
ReminderProposalParseResult(
    visibleText: "我建议创建这个提醒。",
    proposal: expectedProposal
)
```

Add tests for prose-only replies, malformed JSON, and invalid proposals. Invalid
envelopes must throw and must not produce a proposal.

- [ ] **Step 2: Run focused tests and verify RED**

```bash
swift test --package-path DiaryCompanionCore --filter ReminderProposalEnvelopeParserTests
```

Expected: FAIL because the parser does not exist.

- [ ] **Step 3: Implement extraction, decoding, and validation**

Implement:

```swift
public struct ReminderProposalParseResult: Equatable, Sendable {
    public var visibleText: String
    public var proposal: ReminderProposal?
}

public struct ReminderProposalEnvelopeParser: Sendable {
    public func parse(_ text: String) throws -> ReminderProposalParseResult
}
```

Decode a private DTO with a `kind` discriminator, map it into
`ReminderRecurrenceRule`, then call `validate()`.

- [ ] **Step 4: Run tests and commit**

```bash
swift test --package-path DiaryCompanionCore --filter ReminderProposalEnvelopeParserTests
git add DiaryCompanionCore/Sources/DiaryCompanionCore/Reminders DiaryCompanionCore/Tests/DiaryCompanionCoreTests/ReminderProposalEnvelopeParserTests.swift
git commit -m "feat: parse AI reminder proposals"
```

### Task 3: Durable Reminder Proposal Persistence

**Files:**
- Modify: `DiaryCompanionCore/Sources/DiaryCompanionCore/Persistence/PersistedModels.swift`
- Modify: `DiaryCompanionCore/Sources/DiaryCompanionCore/Persistence/DiaryRepository.swift`
- Create: `DiaryCompanionCore/Tests/DiaryCompanionCoreTests/ReminderRepositoryTests.swift`

- [ ] **Step 1: Write failing repository tests**

Assert that the repository can save and fetch a reminder proposal linked to an
assistant message, update it from `pendingConfirmation` to `scheduled`, and
persist independent notification and calendar results:

```swift
#expect(record.notificationResult == "scheduled")
#expect(record.calendarResult == "permissionDenied")
#expect(record.sourceMessageID == messageID)
```

- [ ] **Step 2: Run focused tests and verify RED**

```bash
swift test --package-path DiaryCompanionCore --filter ReminderRepositoryTests
```

- [ ] **Step 3: Expand `ReminderRecord` and repository methods**

Persist encoded recurrence JSON and add:

```swift
public func createReminderProposal(
    _ proposal: ReminderProposal,
    sourceMessageID: UUID?
) throws -> ReminderRecord

public func fetchReminders() throws -> [ReminderRecord]

public func updateReminderExecution(
    id: UUID,
    status: ReminderProposalStatus,
    notificationResult: ReminderExecutionResult,
    calendarResult: ReminderExecutionResult,
    notificationIdentifiers: [String],
    calendarEventIdentifier: String?
) throws
```

- [ ] **Step 4: Run tests and commit**

```bash
swift test --package-path DiaryCompanionCore --filter ReminderRepositoryTests
git add DiaryCompanionCore/Sources/DiaryCompanionCore/Persistence DiaryCompanionCore/Tests/DiaryCompanionCoreTests/ReminderRepositoryTests.swift
git commit -m "feat: persist reminder proposals"
```

### Task 4: Complex Local Notification Expansion

**Files:**
- Modify: `DiaryCompanionCore/Sources/DiaryCompanionCore/Notifications/ReminderRequestFactory.swift`
- Modify: `DiaryCompanionCore/Tests/DiaryCompanionCoreTests/ReminderRequestFactoryTests.swift`

- [ ] **Step 1: Write failing recurrence expansion tests**

Test:

- one-time reminder creates one non-repeating request
- daily, weekday, biweekly, and last-day-of-month rules expand into stable
  concrete requests within a 90-day rolling window
- repeated calls for adjacent rolling windows never change request shape or
  create overlapping identifiers
- notification content uses `.default` sound

Use an injected Gregorian calendar and fixed `windowStart`.

- [ ] **Step 2: Run focused tests and verify RED**

```bash
swift test --package-path DiaryCompanionCore --filter ReminderRequestFactoryTests
```

- [ ] **Step 3: Implement rolling-window notification requests**

Replace the single `makeRequest` path with:

```swift
public func makeRequests(
    reminderID: UUID,
    proposal: ReminderProposal,
    windowStart: Date,
    windowDays: Int = 90
) throws -> [UNNotificationRequest]
```

Expand every recurrence rule into dated non-repeating requests. This keeps
request shape stable across app activations and makes replenishment idempotent.
Native repeating triggers may be added later only with explicit replacement and
revocation semantics.

- [ ] **Step 4: Run tests and commit**

```bash
swift test --package-path DiaryCompanionCore --filter ReminderRequestFactoryTests
git add DiaryCompanionCore/Sources/DiaryCompanionCore/Notifications DiaryCompanionCore/Tests/DiaryCompanionCoreTests/ReminderRequestFactoryTests.swift
git commit -m "feat: expand recurring reminder notifications"
```

### Task 5: Calendar Availability and EventKit Boundary

**Files:**
- Create: `DiaryCompanionCore/Sources/DiaryCompanionCore/Calendar/CalendarAvailabilityService.swift`
- Create: `DiaryCompanionCore/Sources/DiaryCompanionCore/Calendar/EventKitCalendarClient.swift`
- Create: `DiaryCompanionCore/Tests/DiaryCompanionCoreTests/CalendarAvailabilityServiceTests.swift`
- Modify: `DiaryCompanion.xcodeproj/project.pbxproj`

- [ ] **Step 1: Write failing free-slot tests**

Given overlapping busy ranges:

```swift
[
    DateInterval(start: dayAt(9, 0), end: dayAt(10, 0)),
    DateInterval(start: dayAt(9, 30), end: dayAt(11, 0)),
    DateInterval(start: dayAt(13, 0), end: dayAt(14, 0)),
]
```

Assert a 60-minute request inside `09:00...17:00` returns `11:00`. Add tests
for no available slot and earliest deterministic selection.

- [ ] **Step 2: Run focused tests and verify RED**

```bash
swift test --package-path DiaryCompanionCore --filter CalendarAvailabilityServiceTests
```

- [ ] **Step 3: Implement availability calculation**

Implement:

```swift
public struct CalendarAvailabilityService: Sendable {
    public func firstAvailableSlot(
        within searchWindow: DateInterval,
        durationMinutes: Int,
        busyIntervals: [DateInterval]
    ) -> DateInterval?
}
```

Sort, merge overlaps, and return the earliest gap.

- [ ] **Step 4: Add EventKit client**

Implement `EventKitCalendarClient` with methods to request full calendar access,
load events from all visible calendars, and save a repeating event using an
`EKRecurrenceRule` mapped from `ReminderRecurrenceRule`.

- [ ] **Step 5: Add calendar permission descriptions**

Set generated Info.plist values for both Debug and Release:

```text
INFOPLIST_KEY_NSCalendarsFullAccessUsageDescription = "读取已有日程并在你确认后创建提醒事件。";
INFOPLIST_KEY_NSCalendarsWriteOnlyAccessUsageDescription = "在你确认后将提醒写入系统日历。";
```

- [ ] **Step 6: Run tests and commit**

```bash
swift test --package-path DiaryCompanionCore --filter CalendarAvailabilityServiceTests
git add DiaryCompanion.xcodeproj/project.pbxproj DiaryCompanionCore/Sources/DiaryCompanionCore/Calendar DiaryCompanionCore/Tests/DiaryCompanionCoreTests/CalendarAvailabilityServiceTests.swift
git commit -m "feat: find calendar free slots"
```

### Task 6: Confirmation-Only Scheduling Coordinator

**Files:**
- Create: `DiaryCompanionCore/Sources/DiaryCompanionCore/Reminders/ReminderSchedulingCoordinator.swift`
- Create: `DiaryCompanionCore/Tests/DiaryCompanionCoreTests/ReminderSchedulingCoordinatorTests.swift`

- [ ] **Step 1: Write failing coordinator tests**

Use stub notification and calendar clients. Assert:

- no scheduling happens before `confirm(reminderID:)`
- both outputs succeed independently
- notification success survives calendar permission denial
- calendar success survives notification permission denial
- both results persist through `DiaryRepository`

- [ ] **Step 2: Run focused tests and verify RED**

```bash
swift test --package-path DiaryCompanionCore --filter ReminderSchedulingCoordinatorTests
```

- [ ] **Step 3: Implement coordinator**

Define injectable protocols:

```swift
public protocol ReminderNotificationScheduling: Sendable {
    func requestAuthorization() async throws -> Bool
    func add(_ requests: [UNNotificationRequest]) async throws
    func removePendingRequests(withIdentifiers identifiers: [String])
}

public protocol ReminderCalendarScheduling: Sendable {
    func requestFullAccess() async throws -> Bool
    func createEvent(for proposal: ReminderProposal) async throws -> String
    func removeEvent(identifier: String) throws
}
```

Implement `confirm(reminderID:)` so each output is attempted separately and the
repository is updated with partial results. Add coordinator edit and cancel
paths that remove previously scheduled notification identifiers and EventKit
events before resetting repository execution state. Repository methods must not
silently edit or cancel records while external resources are still attached.

- [ ] **Step 4: Run tests and commit**

```bash
swift test --package-path DiaryCompanionCore --filter ReminderSchedulingCoordinatorTests
git add DiaryCompanionCore/Sources/DiaryCompanionCore/Reminders DiaryCompanionCore/Tests/DiaryCompanionCoreTests/ReminderSchedulingCoordinatorTests.swift
git commit -m "feat: confirm reminder scheduling outputs"
```

### Task 7: Chat Reminder Card

**Files:**
- Create: `DiaryCompanion/ReminderProposalCard.swift`
- Modify: `DiaryCompanion/ChatView.swift`
- Create: `DiaryCompanionCore/Sources/DiaryCompanionCore/Reminders/ReminderAssistantPrompt.swift`
- Create: `DiaryCompanionCore/Tests/DiaryCompanionCoreTests/ReminderAssistantPromptTests.swift`

- [ ] **Step 1: Write failing prompt tests**

Extract the reminder instruction into a core helper and assert it states:

- ask a follow-up question when timing is incomplete
- emit the envelope only after timing is complete
- never claim a notification or calendar event was created before confirmation
- use `findFreeTime` when the user asks for automatic arrangement

- [ ] **Step 2: Run focused tests and verify RED**

```bash
swift test --package-path DiaryCompanionCore --filter ReminderAssistantPromptTests
```

- [ ] **Step 3: Implement chat parsing and durable card rendering**

After streaming completes:

1. Parse the assistant message with `ReminderProposalEnvelopeParser`.
2. Replace persisted assistant content with `visibleText`.
3. Save a reminder proposal linked to that assistant message.
4. Query reminder records in `ChatView`.
5. Render `ReminderProposalCard` below the linked message.

During streaming, reuse `ReminderProposalEnvelopeParser.startMarker` and
`endMarker` to buffer structured envelope content instead of persisting or
rendering it incrementally. User-facing prose may continue streaming normally;
JSON must never flash inside a chat bubble.

The card displays title, first start, human-readable recurrence, proposed
duration, scheduling mode, and output results. Wire `确认创建`, `编辑`, and `取消`.
The first edit sheet supports title, start, duration, and enable toggles while
preserving the decoded recurrence.

- [ ] **Step 4: Build the simulator app**

```bash
xcodebuild -project DiaryCompanion.xcodeproj -scheme DiaryCompanion \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -derivedDataPath DerivedData build
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 5: Commit**

```bash
git add DiaryCompanion DiaryCompanionCore/Sources/DiaryCompanionCore/Reminders DiaryCompanionCore/Tests/DiaryCompanionCoreTests/ReminderAssistantPromptTests.swift
git commit -m "feat: render reminder confirmation cards"
```

### Task 8: Rolling Notification Replenishment

**Files:**
- Create: `DiaryCompanionCore/Sources/DiaryCompanionCore/Reminders/ReminderNotificationReplenisher.swift`
- Create: `DiaryCompanionCore/Tests/DiaryCompanionCoreTests/ReminderNotificationReplenisherTests.swift`
- Modify: `DiaryCompanion/DiaryCompanionApp.swift`

- [ ] **Step 1: Write failing replenishment tests**

Use stub repository and notification clients. Assert that app activation:

- schedules future requests for confirmed reminder records
- does not reschedule identifiers already persisted on a reminder
- ignores cancelled reminders
- persists newly scheduled identifiers

- [ ] **Step 2: Run focused tests and verify RED**

```bash
swift test --package-path DiaryCompanionCore --filter ReminderNotificationReplenisherTests
```

- [ ] **Step 3: Implement replenishment**

Implement:

```swift
public struct ReminderNotificationReplenisher: Sendable {
    public func replenish(windowStart: Date = Date()) async throws
}
```

Use `ReminderRequestFactory.makeRequests` with a 90-day horizon, filter out
persisted identifiers, schedule only new requests, and persist the merged
identifier list. Trigger replenishment from the SwiftUI app when scene phase
becomes `.active`.

- [ ] **Step 4: Run tests and commit**

```bash
swift test --package-path DiaryCompanionCore --filter ReminderNotificationReplenisherTests
git add DiaryCompanion DiaryCompanionCore/Sources/DiaryCompanionCore/Reminders DiaryCompanionCore/Tests/DiaryCompanionCoreTests/ReminderNotificationReplenisherTests.swift
git commit -m "feat: replenish rolling reminder notifications"
```

### Task 9: Automatic Calendar Placement in Chat

**Files:**
- Modify: `DiaryCompanion/ReminderProposalCard.swift`
- Modify: `DiaryCompanion/ChatView.swift`
- Modify: `DiaryCompanionCore/Sources/DiaryCompanionCore/Calendar/EventKitCalendarClient.swift`
- Create: `DiaryCompanionCore/Tests/DiaryCompanionCoreTests/ReminderAutoSchedulingTests.swift`

- [ ] **Step 1: Write failing auto-scheduling tests**

Assert:

- `findFreeTime` loads busy intervals from all visible calendars
- earliest available slot replaces the proposal start
- proposal search window comes from the decoded AI envelope
- selected slot matches the recurrence rule before it becomes the first
  occurrence
- denied read access returns a clarification state
- no slot returns a clarification state

- [ ] **Step 2: Run focused tests and verify RED**

```bash
swift test --package-path DiaryCompanionCore --filter ReminderAutoSchedulingTests
```

- [ ] **Step 3: Implement automatic placement**

Before displaying a final card for `findFreeTime`, request EventKit read access,
load visible-calendar intervals for the proposal search window, run
`CalendarAvailabilityService`, filter candidate slots against the recurrence
rule, assign the selected start, and validate it as the concrete first
occurrence before persistence. If access is denied or no recurrence-compatible
slot exists, persist no proposal and append a natural-language clarification
message.

- [ ] **Step 4: Run full verification**

```bash
swift test --package-path DiaryCompanionCore
xcodebuild -project DiaryCompanion.xcodeproj -scheme DiaryCompanion \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -derivedDataPath DerivedData build
git diff --check
```

Expected: all tests pass, `** BUILD SUCCEEDED **`, and no whitespace errors.

- [ ] **Step 5: Install and manually verify**

```bash
xcrun simctl install booted DerivedData/Build/Products/Debug-iphonesimulator/DiaryCompanion.app
xcrun simctl launch --terminate-running-process booted com.liangbowenbill.DiaryCompanion
```

Verify:

- incomplete request produces a follow-up question
- complete request produces a pending confirmation card
- notification authorization appears only after confirmation
- card shows notification and calendar results independently

- [ ] **Step 6: Commit**

```bash
git add DiaryCompanion DiaryCompanionCore
git commit -m "feat: auto-place reminders in calendar gaps"
```

## Final Verification

Run:

```bash
swift test --package-path DiaryCompanionCore
xcodebuild -project DiaryCompanion.xcodeproj -scheme DiaryCompanion \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -derivedDataPath DerivedData build
git diff --check
git status --short
```

Then test calendar writes on a signed iPhone build with real calendar accounts.
The simulator validates UI, notification authorization, and local scheduling;
the signed device validates visible-account EventKit behavior.
