# Vesper

<p align="center">
  <strong>A native iPhone AI companion for conversational reminders, alarms, calendar scheduling, and diary workflows.</strong>
</p>

<p align="center">
  <a href="LICENSE"><img alt="License: MIT" src="https://img.shields.io/badge/License-MIT-black.svg"></a>
  <img alt="iOS 17+" src="https://img.shields.io/badge/iOS-17%2B-blue.svg">
  <img alt="Swift 6" src="https://img.shields.io/badge/Swift-6-orange.svg">
  <img alt="Status" src="https://img.shields.io/badge/status-development_preview-6f42c1.svg">
</p>

Vesper is a personal assistant that lives on iPhone. You speak to it in natural language, and it turns your intent into editable, explicit actions: reminders, notifications, real alarms, calendar events, diary entries, tasks, and debugging logs.

The long-term goal is a private, native companion app that can replace lightweight chat-bot workflows without requiring a Mac service to stay online.

## Highlights

- **Conversational assistant**: ask in natural language, get a structured response.
- **Editable reminder cards**: AI-generated cards can be inspected and edited before execution.
- **Notifications and real alarms**: ordinary reminders use system notifications; explicit alarm requests can use AlarmKit on iOS 26+.
- **Calendar-aware scheduling**: Vesper can inspect visible calendars and place work into free time windows.
- **Calendar-style timeline**: reminders, alarms, diary records, tasks, and summaries are grouped by selected day.
- **Timeline editing and deletion**: tap a reminder or alarm to edit it; swipe left to delete and clean up system resources.
- **Provider settings**: configure OpenAI, DeepSeek, SiliconFlow, Custom OpenAI-compatible providers, Anthropic, and Gemini profiles.
- **Provider connection test**: verify an API key and endpoint before saving.
- **Bilingual UI**: Simplified Chinese and English, with an option to follow system language.
- **Debug export**: export app interaction logs, AI feedback, and tool call records from Settings.
- **Local-first storage**: data is stored on device with SwiftData; provider secrets live in Keychain.

## Current Status

Vesper is a development preview. It is usable for testing personal workflows, but not yet App Store polished.

| Area | Status |
| --- | --- |
| iPhone app | Implemented with SwiftUI |
| Natural-language chat | Implemented |
| OpenAI-compatible streaming chat | Implemented |
| OpenAI / DeepSeek / SiliconFlow / Custom | Supported for active chat when using OpenAI-compatible streaming |
| Anthropic / Gemini | Profiles and request builders exist, but chat streaming is not fully wired yet |
| Editable reminder cards | Implemented |
| System notifications | Implemented |
| Real alarms via AlarmKit | Implemented for iOS 26+ where AlarmKit is available |
| Calendar event creation | Implemented with EventKit |
| Automatic free-time scheduling | Implemented for visible calendars |
| Timeline | Calendar-style view with edit and swipe-delete for reminders/alarms |
| Debug log export | Implemented |
| OAuth login | Not implemented |
| iCloud sync | Not implemented |
| TestFlight helper script | Included |

## How It Works

Vesper follows a confirm-first model:

1. You describe what you want.
2. The assistant asks follow-up questions if the request is ambiguous.
3. When enough information is available, it creates a structured card.
4. You can edit any field.
5. Only after confirmation does Vesper schedule notifications, alarms, or calendar events.

Example:

```text
从下周日开始，每两周周日下午 3 点见我女朋友，提前 30 分钟提醒我。
```

Vesper can turn that into a card containing:

- event title
- first occurrence
- recurrence rule
- duration
- notification toggle and lead time
- real-alarm toggle and lead time
- calendar sync toggle

## App Structure

```text
Vesper
├─ DiaryCompanion/                 iOS SwiftUI app
├─ DiaryCompanionCore/             Swift package with domain logic
│  ├─ Calendar/                    EventKit and free-time scheduling
│  ├─ Networking/                  provider request and streaming clients
│  ├─ Notifications/               notification expansion and replenishment
│  ├─ Alarms/                      AlarmKit abstraction and replenishment
│  ├─ Persistence/                 SwiftData repositories and models
│  ├─ Reminders/                   reminder proposal parsing and scheduling
│  ├─ Security/                    Keychain storage
│  └─ Tools/                       AI tool execution and audit logging
├─ docs/                           user and TestFlight notes
├─ scripts/testflight.sh           TestFlight archive/upload helper
└─ LICENSE                         MIT License
```

## Requirements

- macOS with Xcode installed
- Swift 6 toolchain
- iOS 17+ deployment target
- iOS 26+ device or simulator SDK for AlarmKit-specific behavior
- Apple Developer account for real-device installation or TestFlight distribution

AlarmKit support is conditional. On systems without AlarmKit, ordinary notifications and calendar scheduling still work, but real alarms are unavailable.

## Quick Start

Clone the repository:

```bash
git clone https://github.com/jsyzlbw/vesper.git
cd vesper
```

Run the core test suite:

```bash
swift test --package-path DiaryCompanionCore
```

Build the iOS app for simulator:

```bash
xcodebuild \
  -project DiaryCompanion.xcodeproj \
  -scheme DiaryCompanion \
  -configuration Debug \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO \
  build
```

Or open the project in Xcode:

```bash
open DiaryCompanion.xcodeproj
```

Then select the `DiaryCompanion` scheme, choose a simulator or device, and run.

## Provider Setup

In the app, open **Settings > AI Provider > Add Provider**.

| Provider | Base URL example | Notes |
| --- | --- | --- |
| OpenAI | `https://api.openai.com/v1` | Active chat support |
| DeepSeek | `https://api.deepseek.com` | Requests resolve to `/chat/completions` |
| SiliconFlow | `https://api.siliconflow.com/v1` | OpenAI-compatible |
| Custom | Your service root | Must provide OpenAI-compatible chat completions and SSE |
| Anthropic | `https://api.anthropic.com/v1` | Profile and request construction exist; chat streaming is not fully wired |
| Gemini | `https://generativelanguage.googleapis.com/v1beta` | Profile and request construction exist; chat streaming is not fully wired |

DeepSeek example:

```text
Base URL: https://api.deepseek.com
Resolved endpoint: https://api.deepseek.com/chat/completions
```

Do not enter `https://api.deepseek.com/anthropic`.

API keys are stored in Keychain. Debug exports intentionally exclude provider secrets.

## Reminder, Alarm, and Calendar Behavior

Vesper treats three outputs as separate choices:

- **System notification**: normal notification with sound and vibration.
- **Real alarm**: AlarmKit-backed alarm, intended for explicit alarm requests.
- **Calendar event**: EventKit event in a visible calendar.

Real alarms are only enabled by default when the user explicitly asks for an alarm. A normal reminder request does not silently create a real alarm.

Important AlarmKit note: AlarmKit alarms are managed by Vesper and may not appear in the Apple Clock app list. Use Vesper's status and real-device behavior to verify alarm scheduling.

## Timeline

The Timeline tab is calendar-oriented:

- pick a date
- review reminders and alarms for that day
- tap a reminder/alarm to edit it
- swipe left to delete it
- see diary records, tasks, and summaries grouped under the same date

Editing an existing scheduled reminder cleans up previous notifications, alarms, and calendar events, then reschedules the updated version.

Deleting from the timeline removes the local record after cleaning up the associated system resources.

## Debug Logs

Settings includes **Export debug log**. The exported JSON is meant for development and bug reports. It contains:

- conversations and messages
- AI-visible responses
- diary entries, tasks, summaries, and reminders
- tool audit logs
- provider metadata

It does not export API keys.

## TestFlight

A helper script is included for archive and upload workflows:

```bash
./scripts/testflight.sh preflight
VERSION=0.1.0 BUILD_NUMBER=1 ./scripts/testflight.sh archive
./scripts/testflight.sh upload
```

See [docs/testflight-external-testing-zh-Hans.md](docs/testflight-external-testing-zh-Hans.md) for the full Chinese guide.

## Development Commands

Run all core tests:

```bash
swift test --package-path DiaryCompanionCore
```

Build for simulator without signing:

```bash
xcodebuild \
  -project DiaryCompanion.xcodeproj \
  -scheme DiaryCompanion \
  -configuration Debug \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO \
  build
```

Build for a connected iPhone:

```bash
xcodebuild \
  -project DiaryCompanion.xcodeproj \
  -scheme DiaryCompanion \
  -configuration Debug \
  -destination 'platform=iOS,id=<DEVICE_UDID>' \
  CODE_SIGN_STYLE=Automatic \
  -allowProvisioningUpdates \
  build
```

## Privacy Model

Vesper is designed around explicit user confirmation:

- provider keys are stored in Keychain
- structured actions require confirmation before execution
- reminders and calendar operations are performed locally through iOS APIs
- debug exports omit API keys
- iCloud sync is not implemented yet, so current app data stays on the device

Network requests are made to the configured AI provider when you send a chat message.

## Roadmap

- Finish Anthropic and Gemini streaming chat adapters.
- Add OAuth-based provider login where providers support it.
- Add iCloud sync for personal data.
- Improve timeline density and richer day/week views.
- Add stronger restore and undo flows around destructive actions.
- Prepare App Store metadata and external TestFlight groups.

## Documentation

- [用户说明书](docs/vesper-user-guide-zh-Hans.md)
- [外部 TestFlight 测试发布说明](docs/testflight-external-testing-zh-Hans.md)
- [MIT License](LICENSE)

## License

Vesper is released under the MIT License.
