# Reminder Card Editing Design

## Scope

Improve the conversational reminder card before App Store testing:

- Users can edit an AI-generated reminder proposal before confirming it.
- Card rows use explicit labels instead of ambiguous icons.
- Chinese input behavior is not changed in app code. The reported issue also occurs in
  iOS system apps inside Simulator, so it is tracked as a Simulator keyboard configuration
  issue rather than an application bug.

## Card Presentation

The reminder card stays compact and readable. Each detail row is a button with a label,
value, and chevron:

- `安排方式`: `固定时间` or `自动安排到空闲时间`
- `提醒时间`: selected date and time
- `重复规则`: readable summary such as `每天，持续 7 次`
- `事件持续时间`: readable summary such as `30 分钟`
- `系统通知`: `开启` or `关闭`
- `同步到日历`: `开启` or `关闭`

The previous standalone clock row is replaced by `事件持续时间`. The bell time is shown
separately as `提醒时间`.

The title and notes area is also tappable. Tapping any editable area opens the same native
SwiftUI sheet and focuses or scrolls to the relevant section where practical.

## Editing Sheet

Editing is available only while a reminder has status `pendingConfirmation`. The sheet
edits a draft `ReminderProposal` and does not mutate persisted state until the user taps
`保存`.

The sheet contains:

- title and notes
- scheduling mode picker
- fixed date and time picker
- automatic scheduling search-window start and end pickers
- recurrence-kind picker
- recurrence-specific fields:
  - daily interval
  - weekly interval and selected weekdays
  - monthly interval and day
  - monthly-last-day interval
  - yearly interval, month, and day
  - optional occurrence count
- event duration in minutes
- system notification toggle
- calendar toggle

When automatic scheduling is enabled:

- Preserve the AI-provided search window if present.
- If no search window exists, default to the remaining portion of the current day.
- On save, query all visible calendars and choose the earliest valid free slot.
- Persist the resolved proposal only after automatic scheduling succeeds.
- If calendar permission is denied or no slot exists, keep the sheet open and show a
  readable error.

When fixed scheduling is enabled:

- Preserve the existing selected start if present.
- If no start exists, default to the next rounded 15-minute time.

## Data Flow

`ReminderProposalEditorView` owns editable draft fields and converts them to a validated
`ReminderProposal`. `ChatView` receives a save action and:

1. reconstructs the original proposal from `DiaryRepository`
2. resolves automatic scheduling through `ReminderAutoSchedulingService` when needed
3. calls `ReminderSchedulingCoordinator.edit(reminderID:proposal:)`
4. refreshes the card through SwiftData observation

Saving an edit never creates notifications or calendar events. Creation still requires
the explicit `确认创建` action.

## Error Handling

- Invalid fields are rejected in the sheet with a readable validation message.
- Automatic scheduling permission or availability errors remain visible in the sheet.
- Scheduled, cancelled, and executing reminders do not expose edit affordances.
- Existing coordinator resource cleanup behavior remains unchanged.

## Testing

- Add Core tests for preparing editor defaults:
  - automatic mode preserves the AI search window
  - automatic mode without a window defaults to the remaining day
  - fixed mode without a start rounds to the next 15-minute boundary
- Add Core tests for recurrence display summaries.
- Run the full Core suite.
- Build, install, and launch on the available iPhone Simulator.
- Visually verify row labels, chevrons, sheet layout, save behavior, and unchanged explicit
  confirmation flow.
