# Vesper Reminder Offset and AlarmKit Design

## Goal

Let Vesper distinguish an event time from its reminder time, and add real iPhone alarms for users who explicitly request an alarm.

The motivating acceptance case is:

> Starting Sunday, June 7, 2026, meet my girlfriend every two weeks on Sunday at 15:00 for two hours. Remind me 30 minutes in advance.

Vesper must create a recurring calendar event at `15:00-17:00` and ordinary local notifications at `14:30`. Because the user asked for a reminder rather than an alarm, the real alarm output remains off.

## Terminology

- **Event start:** when the activity actually begins, such as `15:00`.
- **Notification:** an ordinary local notification with sound and vibration.
- **Alarm:** a real AlarmKit alarm available only on iOS 26 and later.
- **Lead time:** the number of minutes before the event start when an output fires.

## Natural Language Rules

Vesper keeps notifications and alarms independent:

- “Remind me 30 minutes before” enables an ordinary notification with a 30-minute lead time.
- “Set an alarm 30 minutes before” enables an AlarmKit alarm with a 30-minute lead time.
- If the user explicitly asks for both a reminder and an alarm, enable both outputs.
- If the user explicitly requests an alarm without separately specifying a notification, enable the alarm only.
- Never enable a real alarm merely because a user asks for a reminder.

When the user explicitly asks for an alarm on iOS versions earlier than 26, Vesper explains that real alarms require iOS 26 or later. It must not silently replace the alarm with an ordinary notification.

## Proposal Model

Extend `ReminderProposal` with independent output lead times:

```swift
public var notificationLeadMinutes: Int
public var alarmEnabled: Bool
public var alarmLeadMinutes: Int
```

`notificationLeadMinutes` defaults to `0` for backward compatibility. `alarmEnabled` defaults to `false`. `alarmLeadMinutes` defaults to `0`.

The existing `start` remains the event start. Recurrence rules continue to operate on event occurrences. Notification and alarm scheduling subtract their configured lead times only when constructing output requests.

Lead times must be between `0` and `10_080` minutes, inclusive. For one-time events, an enabled output may not resolve into the past. For repeating events, scheduling skips resolved output occurrences that are already in the past.

## Assistant Envelope

Extend the reminder proposal envelope with:

```json
{
  "notificationEnabled": true,
  "notificationLeadMinutes": 30,
  "alarmEnabled": false,
  "alarmLeadMinutes": 0
}
```

The system prompt explicitly defines the natural-language rules. The parser defaults absent fields to their backward-compatible values so older model output remains accepted.

## Notification Scheduling

`ReminderRequestFactory` expands recurrence from the event start exactly as it does today. For each concrete event occurrence, it subtracts `notificationLeadMinutes` before creating `UNNotificationRequest`.

This preserves recurrence phase correctly. A recurring event that begins every two weeks on Sunday at `15:00` produces notification fire dates every two weeks on Sunday at `14:30`, without changing the calendar event anchor.

## AlarmKit Scheduling

Add an `AlarmClient` boundary in `DiaryCompanionCore`.

```swift
public protocol AlarmClient: AnyObject {
    func requestAuthorization() async throws -> Bool
    func schedule(
        reminderID: UUID,
        proposal: ReminderProposal,
        windowStart: Date
    ) async throws -> [String]
    func remove(ids: [String]) throws
}
```

The production implementation uses Apple AlarmKit when available on iOS 26 and later. The app must remain buildable for its existing deployment target by guarding AlarmKit code with availability checks.

AlarmKit output follows the same rolling-window policy as notifications: expand the proposal recurrence into a bounded prefix of concrete occurrences, then schedule each occurrence with `Alarm.Schedule.fixed(Date)`. This is intentional: AlarmKit's relative recurrence can express weekly repetition but not every-two-week, monthly, or yearly rules. Fixed concrete alarms keep all supported Vesper recurrence rules consistent. Alarm identifiers are persisted for cancellation, editing, compensation, and recovery.

On older systems, the production client throws a readable `alarmRequiresIOS26` error if an alarm is requested. No ordinary notification is created as an implicit substitute.

## Persistence

Persist:

- `notificationLeadMinutes`
- `alarmEnabled`
- `alarmLeadMinutes`
- alarm execution result
- scheduled alarm identifiers

Existing records migrate with notifications firing at the event time and alarms disabled.

Cleanup journals also persist alarm identifiers so interrupted creation and cancellation can remove AlarmKit outputs consistently with notifications and calendar events.

## Card And Editor UI

The reminder proposal card shows:

1. Event time
2. Recurrence rule
3. Event duration
4. Notification on/off
5. Notification time, such as `14:30 (30 minutes before)`
6. Alarm on/off
7. Alarm time, such as `14:30 (30 minutes before)`, when enabled
8. Calendar sync on/off

Pending proposal rows remain tappable. The editor adds:

- A notification toggle and notification lead-time stepper.
- An alarm toggle and alarm lead-time stepper.
- A short explanation that real alarms require iOS 26 or later.

The UI does not auto-enable alarms when editing an ordinary reminder.

## Error Handling

User-facing bilingual messages cover:

- Notification lead time outside the allowed range.
- Alarm lead time outside the allowed range.
- AlarmKit unavailable because the device runs an iOS version earlier than 26.
- Alarm authorization denied.
- Alarm creation failure.

If alarm creation fails while notification or calendar creation succeeds, the card records the partial result and surfaces a readable message. Cleanup and recovery retain enough identifiers to avoid orphaned outputs.

## Acceptance Tests

### Reminder-Only Scenario

Input:

> Starting next Sunday, I plan to meet my girlfriend every two weeks on Sunday at 3:00 PM. Remind me 30 minutes in advance.

After answering the duration follow-up with `2 hours`, the proposal card must show:

- Event start: `Jun 7, 2026 at 3:00 PM`
- Repeat: every two weeks on Sunday
- Duration: `120 min`
- Notification: on
- Notification time: `Jun 7, 2026 at 2:30 PM`
- Alarm: off
- Calendar: on

After confirmation:

- Calendar event begins at `15:00`.
- Notification fires at `14:30`.
- Future notification occurrences preserve the two-week Sunday phase.
- No AlarmKit alarm is created.

### Explicit Alarm Scenario

Input:

> Starting next Sunday, set an alarm and remind me 30 minutes before I meet my girlfriend every two weeks on Sunday at 3:00 PM.

After answering the duration follow-up, the card shows both notification and alarm enabled at `14:30`. On iOS 26 and later, confirmation creates both outputs. On older systems, confirmation is blocked with the iOS 26 requirement message.

## Verification

Run:

```bash
swift test --package-path DiaryCompanionCore
xcodebuild -project DiaryCompanion.xcodeproj \
  -scheme DiaryCompanion \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  build
```

Then install the simulator build and run both acceptance scenarios through chat. Inspect the generated card before confirming. Confirm only cards whose displayed output times match the scheduled outputs.
