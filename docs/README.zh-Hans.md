# Vesper

<p align="center">
  <strong>一个原生 iPhone AI 私人助理，用自然语言管理提醒、闹钟、日历、日记和任务。</strong>
</p>

<p align="center">
  <a href="../LICENSE"><img alt="License: MIT" src="https://img.shields.io/badge/License-MIT-black.svg"></a>
  <img alt="iOS 17+" src="https://img.shields.io/badge/iOS-17%2B-blue.svg">
  <img alt="Swift 6" src="https://img.shields.io/badge/Swift-6-orange.svg">
  <img alt="Status" src="https://img.shields.io/badge/status-development_preview-6f42c1.svg">
</p>

**简体中文** | [English](README.en.md)

Vesper 是一个运行在 iPhone 上的私人助理。你用自然语言描述意图，它把需求转换成明确、可编辑、可确认的动作：提醒、通知、真闹钟、日历事件、日记、任务和调试日志。

长期目标是做成一个私密、原生、可分发给朋友测试的 iPhone companion app，用来逐步替代轻量 Telegram bot 或临时脚本方案，并且不需要 Mac 常驻服务。

## 功能亮点

- **对话式助手**：直接用自然语言提出要求，AI 生成结构化结果。
- **可编辑提醒卡片**：AI 生成的提醒卡片可以先检查、再编辑、最后确认执行。
- **通知与真闹钟分离**：普通提醒使用系统通知；明确要求“闹钟”时可使用 iOS 26+ AlarmKit。
- **日历感知排期**：可读取可见日历，把事情自动塞进空闲时间。
- **日历式时间线**：按选择日期查看提醒、闹钟、日记、任务和总结。
- **时间线可编辑和删除**：点击提醒/闹钟可编辑，左滑可删除并清理系统资源。
- **AI Provider 设置**：支持配置 OpenAI、DeepSeek、硅基流动、Custom OpenAI-compatible、Anthropic 和 Gemini。
- **Provider 通断测试**：保存前可以测试 API Key 与 endpoint 是否可用。
- **中英双语界面**：支持简体中文、English、跟随系统。
- **调试日志导出**：可在设置中导出用户交互、AI 反馈和工具调用记录。
- **本地优先存储**：数据保存在本机 SwiftData，Provider 密钥保存在 Keychain。

## 当前状态

Vesper 仍是开发预览版，适合个人试用和同学小范围测试，还不是 App Store 完成品。

| 模块 | 状态 |
| --- | --- |
| iPhone App | 已用 SwiftUI 实现 |
| 自然语言对话 | 已实现 |
| OpenAI-compatible 流式聊天 | 已实现 |
| OpenAI / DeepSeek / 硅基流动 / Custom | 使用 OpenAI-compatible 流式协议时可用于当前聊天 |
| Anthropic / Gemini | 已有配置入口和请求构造基础，但聊天流式接入尚未完成 |
| 可编辑提醒卡片 | 已实现 |
| 系统通知 | 已实现 |
| AlarmKit 真闹钟 | iOS 26+ 且系统可用时支持 |
| 日历事件创建 | 已通过 EventKit 实现 |
| 自动寻找空闲时间 | 已支持所有可见日历 |
| 时间线 | 已支持日历式查看、提醒/闹钟编辑和左滑删除 |
| 调试日志导出 | 已实现 |
| OAuth 登录 | 尚未实现 |
| iCloud 同步 | 尚未实现 |
| TestFlight 辅助脚本 | 已包含 |

## 工作方式

Vesper 采用“先确认，再执行”的模式：

1. 你描述需求。
2. 如果信息不完整，AI 会追问。
3. 信息足够后，AI 生成结构化卡片。
4. 你可以编辑任意字段。
5. 只有你确认后，Vesper 才会创建通知、闹钟或日历事件。

示例：

```text
从下周日开始，每两周周日下午 3 点见我女朋友，提前 30 分钟提醒我。
```

Vesper 可以把它变成一张卡片，包括：

- 事件标题
- 第一次发生时间
- 重复规则
- 持续时间
- 系统通知开关和提前量
- 真闹钟开关和提前量
- 是否同步到日历

## 项目结构

```text
Vesper
├─ DiaryCompanion/                 iOS SwiftUI App
├─ DiaryCompanionCore/             Swift Package，核心业务逻辑
│  ├─ Calendar/                    EventKit 与空闲时间排期
│  ├─ Networking/                  Provider 请求和流式客户端
│  ├─ Notifications/               系统通知展开与补充
│  ├─ Alarms/                      AlarmKit 抽象和补充
│  ├─ Persistence/                 SwiftData 仓库和模型
│  ├─ Reminders/                   提醒解析、卡片和调度
│  ├─ Security/                    Keychain 存储
│  └─ Tools/                       AI 工具执行与审计日志
├─ docs/                           用户文档与项目文档
├─ scripts/testflight.sh           TestFlight 归档/上传辅助脚本
└─ LICENSE                         MIT License
```

## 环境要求

- 安装 Xcode 的 macOS
- Swift 6 工具链
- iOS 17+ deployment target
- 如需测试 AlarmKit 真闹钟，需要 iOS 26+ 设备或对应 SDK
- 如需真机安装或 TestFlight 分发，需要 Apple Developer 账号

AlarmKit 是条件编译支持。在没有 AlarmKit 的系统上，普通通知和日历排期仍可工作，但真闹钟不可用。

## 快速开始

克隆仓库：

```bash
git clone https://github.com/jsyzlbw/vesper.git
cd vesper
```

运行核心测试：

```bash
swift test --package-path DiaryCompanionCore
```

构建 iOS 模拟器版本：

```bash
xcodebuild \
  -project DiaryCompanion.xcodeproj \
  -scheme DiaryCompanion \
  -configuration Debug \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO \
  build
```

也可以直接用 Xcode 打开：

```bash
open DiaryCompanion.xcodeproj
```

然后选择 `DiaryCompanion` scheme，选择模拟器或真机运行。

## Provider 设置

在 App 中打开 **设置 > AI Provider > 新增 Provider**。

| Provider | Base URL 示例 | 说明 |
| --- | --- | --- |
| OpenAI | `https://api.openai.com/v1` | 当前聊天可用 |
| DeepSeek | `https://api.deepseek.com` | 会自动解析到 `/chat/completions` |
| 硅基流动 | `https://api.siliconflow.com/v1` | OpenAI-compatible |
| Custom | 你的服务基础地址 | 需要兼容 OpenAI Chat Completions 与 SSE |
| Anthropic | `https://api.anthropic.com/v1` | 已有配置和请求构造，聊天流式接入未完成 |
| Gemini | `https://generativelanguage.googleapis.com/v1beta` | 已有配置和请求构造，聊天流式接入未完成 |

DeepSeek 示例：

```text
Base URL: https://api.deepseek.com
实际 Endpoint: https://api.deepseek.com/chat/completions
```

不需要填写 `https://api.deepseek.com/anthropic`。

API Key 会保存在 Keychain。调试日志导出不会包含 API Key。

## 提醒、闹钟与日历

Vesper 把三种输出独立处理：

- **系统通知**：普通提醒，支持声音和震动。
- **真闹钟**：使用 AlarmKit，适合用户明确要求“闹钟”的场景。
- **日历事件**：通过 EventKit 写入可见日历。

只有用户明确说“闹钟”或 `alarm` 时，Vesper 才会默认开启真闹钟。普通提醒不会偷偷创建真闹钟。

AlarmKit 注意事项：AlarmKit 闹钟由 Vesper 管理，可能不会显示在 Apple“时钟”App 的列表中。是否创建成功应以 Vesper 状态和真机响铃行为为准。

## 时间线

时间线采用日历式视图：

- 选择一个日期
- 查看当天提醒和闹钟
- 点击提醒/闹钟进入编辑
- 左滑提醒/闹钟删除
- 同时查看当天日记、任务和总结

编辑已创建的提醒时，Vesper 会清理旧通知、旧闹钟和旧日历事件，再按新内容重新创建。

从时间线删除时，Vesper 会先清理相关系统资源，再删除本地记录。

## 调试日志

设置中提供 **导出调试日志**。导出的 JSON 用于开发和 bug 反馈，包含：

- 对话和消息
- AI 回复
- 日记、任务、总结和提醒
- 工具调用审计日志
- Provider 元数据

日志不包含 API Key。

## 开发命令

运行全部核心测试：

```bash
swift test --package-path DiaryCompanionCore
```

无签名构建模拟器版本：

```bash
xcodebuild \
  -project DiaryCompanion.xcodeproj \
  -scheme DiaryCompanion \
  -configuration Debug \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO \
  build
```

构建到已连接 iPhone：

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

## 隐私模型

Vesper 围绕明确确认来设计：

- Provider Key 保存在 Keychain
- 结构化动作执行前需要用户确认
- 提醒和日历操作通过本地 iOS API 完成
- 调试导出不会包含 API Key
- iCloud 同步尚未实现，因此当前数据保存在本机

当你发送聊天消息时，应用会向你配置的 AI Provider 发起网络请求。

## 路线图

- 完成 Anthropic 和 Gemini 的流式聊天适配。
- 在 Provider 支持时加入 OAuth 登录。
- 加入 iCloud 同步。
- 优化时间线密度和更丰富的日/周视图。
- 为删除、恢复等破坏性操作加入更完整的撤销机制。
- 完善 App Store 元数据和外部 TestFlight 测试流程。

## 文档

- [用户说明书](vesper-user-guide-zh-Hans.md)
- [MIT License](../LICENSE)

## License

Vesper 使用 MIT License 发布。
