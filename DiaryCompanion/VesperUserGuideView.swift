import SwiftUI

struct VesperUserGuideView: View {
    @Environment(\.vesperLocalization) private var localization

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 28) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Vesper")
                        .font(.largeTitle.bold())
                    Text("对话式私人助理")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                    Text("开发预览版 · iPhone Companion App")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                GuideSection(title: "简介") {
                    Text("Vesper 让你直接用自然语言描述计划。信息足够时，AI 会生成可编辑的提醒卡片；如果你要求安排一天或一组计划，Vesper 会尽量拆成多个独立事项，并按时间排序。只有你点击确认后，应用才会创建通知、真闹钟或日历事件。当前版本无需 Mac 常驻服务。")
                }

                GuideSection(title: "每日对话与历史") {
                    Text("Vesper 会每天自动开启一个新的对话，用来保存当天的自然语言请求、AI 回复和提醒卡片。为了适应晚睡习惯，日期不是午夜 0 点切换，而是每天早上 4 点切换；也就是说，凌晨 0 点到 3:59 的对话仍归入前一天。")
                    Text("在“对话”页右上角点击“历史对话”按钮，可以切换查看之前日期的对话。旧的默认对话会继续保留在历史列表里，不会丢失。")
                }

                GuideSection(title: "设置 AI Provider") {
                    Text("进入“设置”，点击右上角“新增 Provider”。依次选择平台，填写显示名称、Base URL、模型名称和 API Key，检查实际 Endpoint，再点击“测试连接”。成功后保存，并保持 Provider 启用。API Key 保存在系统 Keychain 中。")
                    GuideExample(
                        title: "DeepSeek 示例",
                        text: "Base URL：https://api.deepseek.com\n实际 Endpoint：https://api.deepseek.com/chat/completions\n不需要填写：https://api.deepseek.com/anthropic"
                    )
                    Text("当前聊天支持 OpenAI、DeepSeek、硅基流动，以及兼容 OpenAI Chat Completions 和 SSE 流式响应的 Custom Provider。Anthropic 与 Gemini 暂未接入聊天流。")
                }

                GuideSection(title: "提醒卡片") {
                    Text("直接在“对话”页描述需求。信息不足时，Vesper 会追问。信息完整后，卡片会展示安排方式、事件时间、重复规则、持续时间、通知时间、闹钟时间和日历选项。点击卡片中的任意条目即可编辑，保存后再点击“确认创建”。")
                    GuideExample(
                        text: "从下周日开始，每两周周日下午 3 点学习两小时，提前 30 分钟提醒我。"
                    )
                }

                GuideSection(title: "个人常规事项") {
                    Text("在“设置”的“个人常规事项”里，可以写下每天必做的事和固定习惯，例如三餐、睡眠、通勤、课程、健身、工作时段。Vesper 会把这段内容作为系统提示词的一部分，安排计划时优先避开冲突。")
                    GuideExample(
                        text: "每天 12:00-13:00 午饭；18:30 晚饭；23:30 后不安排高强度学习；周一三五晚上健身。"
                    )
                }

                GuideSection(title: "通知、真闹钟与日历") {
                    Text("普通提醒默认使用系统通知，支持声音与震动，也可以设置提前量。只有你明确说“闹钟”或 alarm 时，Vesper 才会默认开启真闹钟。")
                    Text("真闹钟使用 Apple AlarmKit，仅支持 iOS 26 及以上。它由 Vesper 管理，可能不会显示在 Apple“时钟”App 的列表中。编辑卡片时，你可以独立控制通知、真闹钟和各自的提前量。")
                    Text("开启“同步到日历”后，Vesper 会在你确认时请求日历权限，并创建事件。重复提醒会按规则创建重复日程。")
                }

                GuideSection(title: "早晚提醒与周总结") {
                    Text("在“设置”的“日记与周记”区域，可以设置早晨主动提醒、晚上复盘提醒、通知后多少分钟升级为真闹铃，以及是否启用每周总结。早晚提醒会先发送普通通知；如果你在等待时间内没有打开 App，iOS 26 及以上会使用真闹铃升级提醒。")
                    Text("每周总结可以选择具体星期和时间。到点后，Vesper 会整理本周日历、运动、睡眠和对话记录，并在时间线里生成周记，同时给出生活健康建议。")
                }

                GuideSection(title: "自动排期") {
                    Text("需要灵活安排时，可以让 Vesper 查询所有可见日历，并在指定范围内选择最早可用时段。自动排期完成后仍会生成卡片，等待你确认。")
                    GuideExample(
                        text: "帮我今天安排 45 分钟读书，放进空闲时间，晚上 10 点前完成。"
                    )
                }

                GuideSection(title: "语言") {
                    Text("进入“设置”中的“App 语言”，可选择跟随系统、简体中文或 English。即使 App 使用英文，如果你用中文说话，AI 也会优先用中文回复。")
                }

                GuideSection(title: "权限与确认") {
                    Text("默认策略是“执行前确认”：AI 可以提出建议，卡片生成后仍可编辑；只有你点击确认后，应用才会创建系统资源。取消提醒时，Vesper 会清理已创建的资源。如果创建过程被中断，卡片会提供恢复入口。")
                }

                GuideSection(title: "当前限制") {
                    GuideBulletList(items: [
                        "Anthropic 和 Gemini 尚未接入聊天流。",
                        "OAuth 登录与 iCloud 同步尚未实现，目前使用 API Key，数据保存在本机。",
                        "每天 4 点切换新对话；如果你想把凌晨内容归入当天，需要等后续版本提供自定义切换时间。",
                        "AI 输出仍可能偶尔不生成结构化卡片；重新描述需求通常可以恢复。",
                    ])
                }

                GuideSection(title: "建议测试示例") {
                    GuideExample(
                        title: "普通通知",
                        text: "从下周日开始，每两周周日下午 3 点学习两小时，提前 30 分钟提醒我。"
                    )
                    GuideExample(
                        title: "真闹钟",
                        text: "明天早上 7 点设置闹钟提醒我起床。"
                    )
                    GuideExample(
                        title: "通知与闹钟",
                        text: "明天早上 7 点提醒我起床，并且设置闹钟。"
                    )
                    GuideExample(
                        title: "自动排期",
                        text: "帮我今天安排 45 分钟读书，放进空闲时间，晚上 10 点前完成。"
                    )
                }
            }
            .padding(20)
            .frame(maxWidth: 680, alignment: .leading)
        }
        .navigationTitle(localization.strings.userGuide)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct GuideSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.title3.bold())
            content
                .font(.body)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct GuideExample: View {
    var title: String?
    let text: String

    init(title: String? = nil, text: String) {
        self.title = title
        self.text = text
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let title {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            Text(text)
                .font(.callout.monospaced())
                .textSelection(.enabled)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct GuideBulletList: View {
    let items: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(items, id: \.self) { item in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("•")
                    Text(item)
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        VesperUserGuideView()
    }
}
