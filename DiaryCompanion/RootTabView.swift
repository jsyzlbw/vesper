import DiaryCompanionCore
import SwiftData
import SwiftUI

struct RootTabView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        TabView {
            NavigationStack {
                ChatView()
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
        .task {
            await replenishNotifications()
        }
        .onChange(of: scenePhase) {
            guard scenePhase == .active else {
                return
            }
            Task {
                await replenishNotifications()
            }
        }
    }

    @MainActor
    private func replenishNotifications() async {
        try? await ReminderNotificationReplenisher(
            repository: DiaryRepository(context: modelContext),
            notificationClient: UserNotificationCenterClient()
        ).replenish()
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
