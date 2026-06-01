import DiaryCompanionCore
import SwiftData
import SwiftUI

struct RootTabView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.vesperLocalization) private var localization

    var body: some View {
        TabView {
            NavigationStack {
                ChatView()
            }
            .tabItem {
                Label(localization.strings.chat, systemImage: "bubble.left.and.bubble.right")
            }

            NavigationStack {
                TimelineView()
                    .navigationTitle(localization.strings.timeline)
            }
            .tabItem {
                Label(localization.strings.timeline, systemImage: "clock")
            }

            NavigationStack {
                ProviderSettingsView()
            }
            .tabItem {
                Label(localization.strings.settings, systemImage: "gearshape")
            }

            NavigationStack {
                ContentUnavailableView(
                    localization.strings.noAuditRecords,
                    systemImage: "checklist",
                    description: Text(localization.strings.auditDescription)
                )
                .navigationTitle(localization.strings.audit)
            }
            .tabItem {
                Label(localization.strings.audit, systemImage: "checklist")
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
    @Environment(\.vesperLocalization) private var localization
    @Query(sort: \DiaryRecord.date, order: .reverse)
    private var entries: [DiaryRecord]

    var body: some View {
        if entries.isEmpty {
            ContentUnavailableView(
                localization.strings.noTimelineRecords,
                systemImage: "clock.arrow.circlepath",
                description: Text(localization.strings.timelineDescription)
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
