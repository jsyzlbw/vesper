# Reminder and Calendar Assistant Design

## Goal

Turn natural-language reminder requests into explicit, editable proposals inside
the chat. The app must never silently create a reminder. It creates local
notifications and calendar events only after the user taps a confirmation
button.

Examples:

- "每天晚上 6:55 提醒我洗澡"
- "每隔两周周一安排一次复习，帮我找一个空闲时间"
- "每月最后一天提醒我交房租"

If a request lacks required timing details, such as "周末提醒我复习", the
assistant asks a follow-up question before showing a proposal.

## Product Principles

- The AI interprets intent. The app validates and executes it.
- Every reminder proposal requires an explicit user confirmation.
- The proposal card is the source of truth shown to the user before execution.
- Notifications and calendar events are independent outputs. One may succeed
  when the other fails.
- Scheduling reads all visible calendars when the user requests automatic
  placement.
- The AI proposes a duration based on the activity. The user may edit it.

## Chat Experience

### Complete Reminder Intent

When the user provides enough information, the assistant emits a structured
reminder proposal instead of only replying with prose. The chat renders a
special card containing:

- title
- first occurrence
- human-readable recurrence rule
- AI-proposed duration
- whether automatic free-time placement was used
- notification and calendar outputs
- `确认创建`, `编辑`, and `取消` actions

The proposal starts in `pendingConfirmation`.

### Incomplete Reminder Intent

When the user has a reminder intent but the timing rule is incomplete, the
assistant asks a natural-language follow-up question. It does not create a
proposal card until the rule can be validated.

### Execution Feedback

After confirmation, the same card transitions to an execution result:

- notification scheduled and calendar event created
- notification scheduled but calendar access denied
- calendar event created but notifications denied
- both failed, with actionable explanations

Partial completion is valid and remains visible in chat.

## Structured Proposal

The AI returns a JSON envelope alongside its user-facing reply. The envelope is
decoded into a domain model before any UI or side effect occurs.

```swift
struct ReminderProposal {
    var title: String
    var notes: String
    var start: Date?
    var durationMinutes: Int
    var recurrence: RecurrenceRule
    var schedulingMode: SchedulingMode
    var notificationEnabled: Bool
    var calendarEnabled: Bool
}
```

`SchedulingMode` supports:

- `fixed`: preserve the user's explicit time
- `findFreeTime`: search all visible calendars and propose an available slot

`RecurrenceRule` is a structured app-owned representation. It supports:

- one-time reminders
- daily, weekly, monthly, and yearly rules
- selected weekdays
- intervals such as every two weeks
- positional rules such as the last day of each month
- an end date or occurrence count when the user specifies one

The app validates the decoded rule and asks the user to clarify unsupported or
ambiguous cases.

## Calendar Scheduling

`CalendarAvailabilityService` uses EventKit to read all visible calendars after
the user grants calendar access. For `findFreeTime`, it:

1. Defines the search window from the user's request.
2. Loads existing events from every visible calendar.
3. Merges overlapping busy ranges.
4. Finds a slot long enough for the AI-proposed duration.
5. Returns a concrete proposed start time for the confirmation card.

The first implementation should prefer deterministic placement: select the
earliest valid free slot within the requested window. The AI interprets the
window and duration, while the app performs the actual conflict calculation.

On confirmation, `CalendarEventScheduler` writes an EventKit event and stores
its external identifier in the app reminder record.

## Notifications

`ReminderRequestFactory` expands to convert validated recurrence rules into
`UNCalendarNotificationTrigger` requests. Notification content uses the default
sound. iOS controls vibration behavior according to system notification
settings.

For recurrence shapes that cannot be expressed as one repeating
`UNCalendarNotificationTrigger`, the app schedules a bounded rolling window of
concrete notifications and replenishes it when the app next becomes active.

The app requests notification authorization when the user first confirms a
proposal that needs notifications.

## Persistence

`ReminderRecord` expands from a basic fire date into a durable proposal and
execution record:

- proposal status
- title and notes
- first occurrence
- duration
- encoded recurrence rule
- scheduling mode
- local notification identifiers
- EventKit calendar event identifier
- notification execution result
- calendar execution result
- source message identifier

The chat card stores or references a reminder proposal identifier so it can
render after relaunch and display later execution results.

## Permissions

Reminder confirmation has two separate system permission paths:

- `UNUserNotificationCenter` for local notifications
- EventKit calendar access for reading availability and creating events

The existing app tool permission policy remains an additional app-level gate.
Reminder creation always requires confirmation even if a future settings screen
allows automatic execution for other tool categories.

Automatic placement requires EventKit read access before the card can show a
final proposed time. If calendar read access is denied, the assistant explains
that it cannot place the event automatically and asks the user to choose a
specific time.

## Assistant Integration

The chat request includes a system instruction describing the structured
reminder proposal schema and the confirmation requirement. Provider responses
are parsed into:

- normal assistant text
- clarification text
- a validated reminder proposal

The first implementation uses a provider-neutral JSON envelope in assistant
text so it works with the existing OpenAI-compatible streaming transport.
Native provider tool-calling can be added later without changing the domain
model or card UI.

## Error Handling

- Invalid AI JSON: show the assistant text, log a redacted diagnostic, and do
  not create a proposal.
- Ambiguous recurrence rule: ask a follow-up question.
- Notification permission denied: preserve calendar success and explain the
  notification failure.
- Calendar permission denied: preserve notification success and explain the
  calendar failure.
- EventKit write failure: preserve the local reminder and notification result,
  and expose a retry action on the card.
- Notification scheduling failure: preserve the calendar result and expose a
  retry action on the card.

## Testing

Unit tests cover:

- decoding valid reminder proposal envelopes
- rejecting malformed or ambiguous rules
- recurrence conversion for one-time, weekday, interval, and last-day-of-month
  cases
- deterministic free-slot selection across overlapping calendar events
- notification rolling-window expansion
- confirmation-only execution
- partial completion states

App-level tests cover:

- chat renders a pending proposal card
- edit and cancel actions
- confirmation transitions the card to success or partial completion
- permission-denied messages

Manual simulator testing covers notification authorization and local
notification scheduling. Calendar write verification should also be run on a
signed iPhone build because EventKit behavior and available calendars depend on
the device account state.

## Scope Notes

This feature does not attempt to execute background AI work at arbitrary times.
The scheduled output is an iOS local notification and an EventKit calendar
event. No always-on Mac service is required.

