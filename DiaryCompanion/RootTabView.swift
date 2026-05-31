import DiaryCompanionCore
import SwiftData
import SwiftUI

struct RootTabView: View {
    var body: some View {
        TabView {
            NavigationStack {
                ContentUnavailableView(
                    "开始对话",
                    systemImage: "bubble.left.and.bubble.right",
                    description: Text("连接 AI Provider 后，通过自然语言记录生活。")
                )
                .navigationTitle("对话")
            }
            .tabItem {
                Label("对话", systemImage: "bubble.left.and.bubble.right")
            }

            NavigationStack {
                TimelineView()
                    .navigationTitle("时间线")
            }
            .tabItem {
                Label("时间线", systemImage: "clock")
            }

            NavigationStack {
                ProviderSettingsView()
            }
            .tabItem {
                Label("设置", systemImage: "gearshape")
            }

            NavigationStack {
                ContentUnavailableView(
                    "暂无审计记录",
                    systemImage: "checklist",
                    description: Text("AI 的工具调用记录会显示在这里。")
                )
                .navigationTitle("审计")
            }
            .tabItem {
                Label("审计", systemImage: "checklist")
            }
        }
    }
}

private struct TimelineView: View {
    @Query(sort: \DiaryRecord.date, order: .reverse)
    private var entries: [DiaryRecord]

    var body: some View {
        if entries.isEmpty {
            ContentUnavailableView(
                "暂无记录",
                systemImage: "clock.arrow.circlepath",
                description: Text("AI 保存的日记、任务和总结会出现在这里。")
            )
        } else {
            List(entries) { entry in
                VStack(alignment: .leading, spacing: 6) {
                    Text(entry.date, style: .date)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(entry.content)
                }
            }
        }
    }
}

#Preview {
    RootTabView()
        .modelContainer(for: DiarySchema.models, inMemory: true)
}
