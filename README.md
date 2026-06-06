# Vesper

<p align="center">
  <img src="docs/assets/readme/vesper-hero.svg" alt="Vesper product preview" width="100%">
</p>

<p align="center">
  <a href="LICENSE"><img alt="License: MIT" src="https://img.shields.io/badge/License-MIT-111827.svg"></a>
  <img alt="iOS 17+" src="https://img.shields.io/badge/iOS-17%2B-2B8CFF.svg">
  <img alt="Swift 6" src="https://img.shields.io/badge/Swift-6-F97316.svg">
  <img alt="Status" src="https://img.shields.io/badge/status-development_preview-7C3AED.svg">
  <a href="https://github.com/jsyzlbw/vesper/stargazers"><img alt="GitHub stars" src="https://img.shields.io/github/stars/jsyzlbw/vesper?style=social"></a>
</p>

<p align="center">
  <strong>A native iPhone AI companion that turns natural language into editable reminders, alarms, calendar plans, diary entries, and health-aware weekly reviews.</strong>
</p>

<p align="center">
  <a href="https://github.com/jsyzlbw/vesper/releases/latest">Download development IPA</a>
  ·
  <a href="docs/vesper-user-guide-zh-Hans.md">中文说明书</a>
  ·
  <a href="https://github.com/jsyzlbw/vesper/stargazers">Star Vesper</a>
</p>

<table>
  <tr>
    <th>Repository Signal</th>
    <th>Live Badge</th>
  </tr>
  <tr>
    <td>Stars</td>
    <td><img alt="GitHub Repo stars" src="https://img.shields.io/github/stars/jsyzlbw/vesper?style=flat-square"></td>
  </tr>
  <tr>
    <td>Forks</td>
    <td><img alt="GitHub forks" src="https://img.shields.io/github/forks/jsyzlbw/vesper?style=flat-square"></td>
  </tr>
  <tr>
    <td>Latest release</td>
    <td><img alt="Latest release" src="https://img.shields.io/github/v/release/jsyzlbw/vesper?include_prereleases&style=flat-square"></td>
  </tr>
  <tr>
    <td>Open issues</td>
    <td><img alt="GitHub issues" src="https://img.shields.io/github/issues/jsyzlbw/vesper?style=flat-square"></td>
  </tr>
</table>

<details open>
<summary><strong>简体中文</strong></summary>

## 为什么值得看

Vesper 是一个原生 iPhone 私人助理。你不用学习命令，不用配置一堆自动化规则，只要像聊天一样描述意图：  
“明天 8:30 学深度学习，下午健身，记得留出吃饭时间。”  
Vesper 会把它拆成明确、可编辑、可确认的事项，再写入时间线、通知、真闹钟或日历。

核心原则很简单：AI 负责理解与提案，用户负责确认，App 负责可靠执行。

## 当前功能

- **对话式执行**：用自然语言创建提醒、闹钟、日历事项、日记和计划。
- **多事项拆分**：完整日程不会再塞进一张大卡片；每个事项独立成卡，并按时间排序。
- **可编辑卡片**：确认前可以点开修改标题、时间、重复、持续时间、通知、真闹钟、日历同步。
- **真实提醒链路**：普通通知支持声音与震动；iOS 26+ 可使用 AlarmKit 真闹钟。
- **日历式时间线**：提醒、闹钟、日历、日记、健康摘要按日期查看。
- **日记与周记**：早晨主动发日程简报，晚上提醒复盘，每周生成总结和生活健康建议。
- **健康上下文**：可读取 Health 中的运动、能量、睡眠信息，写入日记/周记。
- **个人常规事项**：在设置里写下吃饭、睡觉、通勤、课程、健身等习惯，AI 排计划时会作为系统提示词参考。
- **多 Provider**：支持 OpenAI、Anthropic、Gemini、DeepSeek、硅基流动和 Custom Provider 配置。
- **本地优先**：API Key 存 Keychain，记录保存在本机 SwiftData；执行前默认需要确认。
- **调试日志导出**：导出用户消息、AI 回复、工具调用、提醒与设置，方便复盘和 debug。

## 安装测试版

最新开发版 IPA 在 [Releases](https://github.com/jsyzlbw/vesper/releases/latest)。  
你可以用爱思助手 / 3uTools 一键安装，但当前 IPA 是开发签名版本，目标 iPhone 必须包含在对应 provisioning profile 中。

如果你想自己构建：

```bash
git clone https://github.com/jsyzlbw/vesper.git
cd vesper
swift test --package-path DiaryCompanionCore
xcodebuild -project DiaryCompanion.xcodeproj -scheme DiaryCompanion -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

## 项目状态

Vesper 仍是 development preview。我正在优先打磨三件事：

- 更可靠的自然语言结构化解析。
- 更像日历的时间线体验。
- 更适合 TestFlight / 同学内测的分发流程。

给一个 star 会很有帮助：它能让我知道这个方向值得继续做下去，也能让更多人看到这个“小而认真”的私人助理实验。

</details>

<details>
<summary><strong>English</strong></summary>

## Why It Matters

Vesper is a native iPhone private assistant. You do not learn commands or build automation rules. You simply describe intent in natural language:  
“Plan tomorrow: deep learning at 8:30, gym in the afternoon, and keep meals open.”  
Vesper turns that into explicit, editable, confirmable actions, then writes them to the timeline, notifications, real alarms, or calendars.

The product principle is deliberately calm: AI understands and proposes, the user confirms, the app executes reliably.

## Current Features

- **Conversational execution**: create reminders, alarms, calendar events, diary entries, and plans with natural language.
- **Multi-item planning**: full-day plans are split into individual cards and sorted by time instead of being stored as one giant reminder.
- **Editable cards**: edit title, time, recurrence, duration, notifications, real alarms, and calendar sync before confirming.
- **Reliable outputs**: local notifications support sound and vibration; iOS 26+ can use AlarmKit real alarms.
- **Calendar-like timeline**: reminders, alarms, calendar events, journals, and health summaries are grouped by date.
- **Diary and weekly review**: morning schedule briefs, evening reflections, and weekly lifestyle-health suggestions.
- **Health context**: optional HealthKit activity, energy, and sleep data can be written into diary and weekly reviews.
- **Personal routines**: define meals, sleep, commute, classes, workouts, and other habits in Settings; Vesper injects them into the system prompt for planning.
- **Multiple providers**: OpenAI, Anthropic, Gemini, DeepSeek, SiliconFlow, and custom provider configuration.
- **Local-first posture**: API keys live in Keychain, records live in local SwiftData, and actions require confirmation by default.
- **Debug export**: export user messages, AI responses, tool calls, reminders, and settings for troubleshooting.

## Install The Preview

The latest development IPA is available from [Releases](https://github.com/jsyzlbw/vesper/releases/latest).  
You can install it with tools such as 3uTools, but the current IPA is development-signed, so the target iPhone must be included in the provisioning profile.

To build locally:

```bash
git clone https://github.com/jsyzlbw/vesper.git
cd vesper
swift test --package-path DiaryCompanionCore
xcodebuild -project DiaryCompanion.xcodeproj -scheme DiaryCompanion -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

## Project Status

Vesper is still a development preview. The near-term focus is:

- More reliable natural-language structuring.
- A more calendar-like timeline.
- A smoother TestFlight / small-group beta flow.

If this feels useful, starring the repo helps the project reach more testers and gives a clear signal that this direction is worth continuing.

</details>

## Star History

<a href="https://star-history.com/#jsyzlbw/vesper&Date">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="https://api.star-history.com/svg?repos=jsyzlbw/vesper&type=Date&theme=dark">
    <img alt="Vesper star history" src="https://api.star-history.com/svg?repos=jsyzlbw/vesper&type=Date">
  </picture>
</a>

## License

MIT. See [LICENSE](LICENSE).
