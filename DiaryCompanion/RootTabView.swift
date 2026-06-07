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
        }
        .task {
            await replenishReminderOutputs()
            await refreshJournalAutomation()
        }
        .onChange(of: scenePhase) {
            guard scenePhase == .active else {
                return
            }
            Task {
                await replenishReminderOutputs()
                await refreshJournalAutomation()
            }
        }
    }

    @MainActor
    private func replenishReminderOutputs() async {
        try? await ReminderNotificationReplenisher(
            repository: DiaryRepository(context: modelContext),
            notificationClient: UserNotificationCenterClient()
        ).replenish()
        try? await ReminderAlarmReplenisher(
            repository: DiaryRepository(context: modelContext),
            alarmClient: makeAlarmClient()
        ).replenish()
    }

    @MainActor
    private func refreshJournalAutomation() async {
        await JournalAutomationService(
            context: modelContext,
            localization: localization
        ).refresh()
    }
}

private struct TimelineView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.vesperLocalization) private var localization
    @State private var selectedDate = Date()
    @State private var editorPresentation: TimelineReminderEditorPresentation?
    @State private var errorMessage: String?
    @Query(sort: \DiaryRecord.date, order: .reverse)
    private var entries: [DiaryRecord]
    @Query(sort: \ReminderRecord.fireDate)
    private var reminders: [ReminderRecord]
    @Query
    private var tasks: [TaskRecord]
    @Query(sort: \DailySummaryRecord.date, order: .reverse)
    private var summaries: [DailySummaryRecord]
    @Query(sort: \JournalRecord.date, order: .reverse)
    private var journals: [JournalRecord]
    @Query(sort: \CalendarEventSnapshotRecord.startDate)
    private var calendarEvents: [CalendarEventSnapshotRecord]
    @Query(sort: \HealthDailySummaryRecord.date, order: .reverse)
    private var healthSummaries: [HealthDailySummaryRecord]

    var body: some View {
        if entries.isEmpty,
           reminders.isEmpty,
           tasks.isEmpty,
           summaries.isEmpty,
           journals.isEmpty,
           calendarEvents.isEmpty,
           healthSummaries.isEmpty {
            ContentUnavailableView(
                localization.strings.noTimelineRecords,
                systemImage: "clock.arrow.circlepath",
                description: Text(localization.strings.timelineDescription)
            )
        } else {
            List {
                Section {
                    DatePicker(
                        localization.strings.timelineCalendar,
                        selection: $selectedDate,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.graphical)
                    .labelsHidden()
                }

                if dayReminders.isEmpty,
                   dayEntries.isEmpty,
                   dayTasks.isEmpty,
                   daySummaries.isEmpty,
                   dayJournals.isEmpty,
                   dayCalendarEvents.isEmpty,
                   dayHealthSummaries.isEmpty {
                    ContentUnavailableView(
                        localization.strings.noRecordsForSelectedDate,
                        systemImage: "calendar",
                        description: Text(selectedDate.formatted(
                            Date.FormatStyle(date: .abbreviated, time: .omitted)
                                .locale(localization.locale)
                        ))
                    )
                    .listRowBackground(Color.clear)
                }

                if !dayJournals.isEmpty {
                    Section(localization.strings.journal) {
                        ForEach(dayJournals) { journal in
                            JournalTimelineCard(journal: journal)
                        }
                    }
                }

                if !dayCalendarEvents.isEmpty {
                    Section(localization.strings.calendarEvents) {
                        ForEach(dayCalendarEvents) { event in
                            CalendarEventTimelineRow(event: event)
                        }
                    }
                }

                if !dayHealthSummaries.isEmpty {
                    Section(localization.strings.healthSnapshotHeader) {
                        ForEach(dayHealthSummaries) { summary in
                            HealthTimelineRow(summary: summary)
                        }
                    }
                }

                if !dayReminders.isEmpty {
                    Section(localization.strings.remindersAndAlarms) {
                        ForEach(dayReminders) { reminder in
                            Button {
                                edit(reminder)
                            } label: {
                                ReminderTimelineRow(reminder: reminder)
                            }
                            .buttonStyle(.plain)
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    delete(reminder)
                                } label: {
                                    Label(localization.strings.delete, systemImage: "trash")
                                }
                            }
                        }
                    }
                }

                if !dayEntries.isEmpty || !dayTasks.isEmpty {
                    Section(localization.strings.diaryAndTasks) {
                        ForEach(dayEntries) { entry in
                            TimelineTextRow(
                                systemImage: "book.closed",
                                title: entry.content,
                                subtitle: entry.date.formatted(
                                    Date.FormatStyle(date: .abbreviated, time: .shortened)
                                        .locale(localization.locale)
                                )
                            )
                        }
                        ForEach(dayTasks) { task in
                            TimelineTextRow(
                                systemImage: task.isCompleted ? "checkmark.circle.fill" : "circle",
                                title: task.title,
                                subtitle: taskSubtitle(task)
                            )
                        }
                    }
                }

                if !daySummaries.isEmpty {
                    Section(localization.strings.summaries) {
                        ForEach(daySummaries) { summary in
                            TimelineTextRow(
                                systemImage: "sparkles",
                                title: summary.content,
                                subtitle: summary.date.formatted(
                                    Date.FormatStyle(date: .abbreviated, time: .omitted)
                                        .locale(localization.locale)
                                )
                            )
                        }
                    }
                }
            }
            .sheet(item: $editorPresentation) { presentation in
                ReminderProposalEditorView(
                    originalProposal: presentation.proposal
                ) { proposal in
                    try await saveEditedProposal(
                        proposal,
                        reminderID: presentation.reminderID
                    )
                }
            }
            .alert(localization.strings.operationFailed, isPresented: errorBinding) {
                Button(localization.strings.ok, role: .cancel) {
                    errorMessage = nil
                }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private var dayEntries: [DiaryRecord] {
        entries.filter { isSelectedDay($0.date) }
    }

    private var dayReminders: [ReminderRecord] {
        reminders
            .filter { isSelectedDay(reminderDate($0)) }
            .sorted { reminderDate($0) < reminderDate($1) }
    }

    private var dayTasks: [TaskRecord] {
        sortedTasks.filter { task in
            guard let dueAt = task.dueAt else {
                return false
            }
            return isSelectedDay(dueAt)
        }
    }

    private var daySummaries: [DailySummaryRecord] {
        summaries.filter { isSelectedDay($0.date) }
    }

    private var dayJournals: [JournalRecord] {
        journals
            .filter { isSelectedDay($0.date) }
            .sorted { $0.date < $1.date }
    }

    private var dayCalendarEvents: [CalendarEventSnapshotRecord] {
        calendarEvents
            .filter { isSelectedDay($0.startDate) }
            .sorted { $0.startDate < $1.startDate }
    }

    private var dayHealthSummaries: [HealthDailySummaryRecord] {
        healthSummaries.filter { isSelectedDay($0.date) }
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    errorMessage = nil
                }
            }
        )
    }

    private var sortedTasks: [TaskRecord] {
        tasks.sorted {
            switch ($0.dueAt, $1.dueAt) {
            case let (lhs?, rhs?):
                lhs < rhs
            case (_?, nil):
                true
            case (nil, _?):
                false
            case (nil, nil):
                $0.title.localizedCompare($1.title) == .orderedAscending
            }
        }
    }

    private func taskSubtitle(_ task: TaskRecord) -> String {
        let state = task.isCompleted ? localization.strings.completed : localization.strings.open
        guard let dueAt = task.dueAt else {
            return "\(state) · \(localization.strings.noDueDate)"
        }
        let due = dueAt.formatted(
            Date.FormatStyle(date: .abbreviated, time: .shortened)
                .locale(localization.locale)
        )
        return "\(state) · \(due)"
    }

    private func isSelectedDay(_ date: Date) -> Bool {
        Calendar.current.isDate(date, inSameDayAs: selectedDate)
    }

    private func reminderDate(_ reminder: ReminderRecord) -> Date {
        reminder.firstOccurrence
            ?? reminder.searchWindowStart
            ?? reminder.fireDate
    }

    private func edit(_ reminder: ReminderRecord) {
        guard let proposal = try? DiaryRepository(context: modelContext)
            .reminderProposal(from: reminder) else {
            return
        }
        editorPresentation = TimelineReminderEditorPresentation(
            reminderID: reminder.id,
            proposal: proposal
        )
    }

    private func delete(_ reminder: ReminderRecord) {
        do {
            try ReminderSchedulingCoordinator(
                repository: DiaryRepository(context: modelContext),
                notificationClient: UserNotificationCenterClient(),
                alarmClient: makeAlarmClient(),
                calendarClient: EventKitCalendarClient()
            ).delete(reminderID: reminder.id)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func saveEditedProposal(
        _ proposal: ReminderProposal,
        reminderID: UUID
    ) async throws {
        let calendarClient = EventKitCalendarClient()
        let resolvedProposal = try await ReminderAutoSchedulingService(
            calendarClient: calendarClient
        ).resolve(proposal)
        try await ReminderSchedulingCoordinator(
            repository: DiaryRepository(context: modelContext),
            notificationClient: UserNotificationCenterClient(),
            alarmClient: makeAlarmClient(),
            calendarClient: calendarClient
        ).editAndConfirm(reminderID: reminderID, proposal: resolvedProposal)
    }
}

private struct TimelineReminderEditorPresentation: Identifiable {
    let reminderID: UUID
    let proposal: ReminderProposal

    var id: UUID {
        reminderID
    }
}

private struct ReminderTimelineRow: View {
    @Environment(\.vesperLocalization) private var localization
    let reminder: ReminderRecord

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: reminder.alarmEnabled ? "alarm.fill" : "bell.fill")
                .font(.headline)
                .foregroundStyle(iconColor)
                .frame(width: 32, height: 32)
                .background(iconColor.opacity(0.13))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 7) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(reminder.title)
                        .font(.headline)
                    Spacer()
                    Text(statusText)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(statusColor)
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
                Text(timeText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if !reminder.notes.isEmpty {
                    Text(reminder.notes)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                HStack(spacing: 6) {
                    if reminder.notificationEnabled {
                        ReminderOutputChip(
                            title: localization.strings.notificationOutput,
                            systemImage: "bell.badge",
                            result: localization.strings.executionResultLabel(
                                reminder.notificationResult
                            )
                        )
                    }
                    if reminder.alarmEnabled {
                        ReminderOutputChip(
                            title: localization.strings.alarmOutput,
                            systemImage: "alarm",
                            result: localization.strings.executionResultLabel(
                                reminder.alarmResult
                            )
                        )
                    }
                    if reminder.calendarEnabled {
                        ReminderOutputChip(
                            title: localization.strings.calendarOutput,
                            systemImage: "calendar",
                            result: localization.strings.executionResultLabel(
                                reminder.calendarResult
                            )
                        )
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .padding(.vertical, 4)
    }

    private var timeText: String {
        if let firstOccurrence = reminder.firstOccurrence {
            return firstOccurrence.formatted(
                Date.FormatStyle(date: .abbreviated, time: .shortened)
                    .locale(localization.locale)
            )
        }
        if let start = reminder.searchWindowStart,
           let end = reminder.searchWindowEnd {
            let startText = start.formatted(
                Date.FormatStyle(date: .abbreviated, time: .shortened)
                    .locale(localization.locale)
            )
            let endText = end.formatted(
                Date.FormatStyle(date: .omitted, time: .shortened)
                    .locale(localization.locale)
            )
            return localization.strings.automaticRange(startText, endText)
        }
        return localization.strings.waitingForTime
    }

    private var statusText: String {
        guard let status = ReminderProposalStatus(rawValue: reminder.status) else {
            return localization.strings.invalidReminderStatus
        }
        return localization.strings.statusLabel(status)
    }

    private var statusColor: Color {
        switch ReminderProposalStatus(rawValue: reminder.status) {
        case .scheduled:
            .green
        case .executing:
            .orange
        case .cancelled:
            .secondary
        case .pendingConfirmation:
            .accentColor
        case nil:
            .red
        }
    }

    private var iconColor: Color {
        reminder.alarmEnabled ? .orange : .accentColor
    }
}

private struct ReminderOutputChip: View {
    let title: String
    let systemImage: String
    let result: String

    var body: some View {
        Label("\(title) · \(result)", systemImage: systemImage)
            .font(.caption2.weight(.medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(.secondarySystemBackground))
            .clipShape(Capsule())
    }
}

private struct JournalTimelineCard: View {
    @Environment(\.vesperLocalization) private var localization
    let journal: JournalRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Label(kindLabel, systemImage: kindIcon)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
                Spacer()
                Text(journal.date, style: .time)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(journal.title)
                .font(.title3.weight(.semibold))

            Text(journal.body)
                .font(.body)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [
                    Color.accentColor.opacity(0.12),
                    Color(.secondarySystemGroupedBackground),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
        .listRowBackground(Color.clear)
    }

    private var kindLabel: String {
        switch JournalKind(rawValue: journal.kind) {
        case .morningPlan:
            localization.strings.morningJournalTitle
        case .eveningReview:
            localization.strings.eveningJournalTitle
        case .weeklySummary:
            localization.strings.weeklyJournalTitle
        case nil:
            localization.strings.journal
        }
    }

    private var kindIcon: String {
        switch JournalKind(rawValue: journal.kind) {
        case .morningPlan:
            "sun.max.fill"
        case .eveningReview:
            "moon.stars.fill"
        case .weeklySummary:
            "sparkles"
        case nil:
            "book.closed.fill"
        }
    }
}

private struct CalendarEventTimelineRow: View {
    @Environment(\.vesperLocalization) private var localization
    let event: CalendarEventSnapshotRecord

    var body: some View {
        TimelineTextRow(
            systemImage: event.isAllDay ? "calendar" : "calendar.badge.clock",
            title: event.title,
            subtitle: subtitle
        )
    }

    private var subtitle: String {
        if event.isAllDay {
            return "\(localization.strings.allDay) · \(event.calendarTitle)"
        }
        let start = event.startDate.formatted(
            Date.FormatStyle(date: .omitted, time: .shortened)
                .locale(localization.locale)
        )
        let end = event.endDate.formatted(
            Date.FormatStyle(date: .omitted, time: .shortened)
                .locale(localization.locale)
        )
        return "\(start)-\(end) · \(event.calendarTitle)"
    }
}

private struct HealthTimelineRow: View {
    @Environment(\.vesperLocalization) private var localization
    let summary: HealthDailySummaryRecord

    var body: some View {
        TimelineTextRow(
            systemImage: "heart.text.square",
            title: localization.strings.healthSummaryLine(
                steps: Int(summary.stepCount.rounded()),
                energy: Int(summary.activeEnergyKilocalories.rounded()),
                exerciseMinutes: Int(summary.exerciseMinutes.rounded()),
                sleepHours: VesperHealthSummarySnapshot(
                    date: summary.date,
                    stepCount: summary.stepCount,
                    activeEnergyKilocalories: summary.activeEnergyKilocalories,
                    exerciseMinutes: summary.exerciseMinutes,
                    sleepMinutes: summary.sleepMinutes,
                    sleepInBedMinutes: summary.sleepInBedMinutes,
                    sourceDescription: summary.sourceDescription
                ).effectiveSleepMinutes / 60
            ),
            subtitle: summary.sourceDescription.isEmpty
                ? "HealthKit"
                : summary.sourceDescription
        )
    }
}

private struct TimelineTextRow: View {
    let systemImage: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .font(.headline)
                .foregroundStyle(Color.accentColor)
                .frame(width: 28, height: 28)
            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.body)
                    .lineLimit(3)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 3)
        .textSelection(.enabled)
    }
}

private struct AuditView: View {
    @Environment(\.vesperLocalization) private var localization
    @Query(sort: \ToolAuditRecord.createdAt, order: .reverse)
    private var logs: [ToolAuditRecord]

    var body: some View {
        if logs.isEmpty {
            ContentUnavailableView(
                localization.strings.noAuditRecords,
                systemImage: "checklist",
                description: Text(localization.strings.auditDescription)
            )
        } else {
            List(logs) { log in
                AuditLogRow(log: log)
            }
        }
    }
}

private struct AuditLogRow: View {
    @Environment(\.vesperLocalization) private var localization
    let log: ToolAuditRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(log.toolName)
                    .font(.headline)
                Spacer()
                Text(log.createdAt, style: .time)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                AuditBadge(title: localization.strings.decision, value: log.decision)
                AuditBadge(title: localization.strings.result, value: log.result)
            }

            if !parameterSummary.isEmpty {
                Divider()
                Text(localization.strings.parameters)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                ForEach(parameterSummary, id: \.key) { item in
                    HStack(alignment: .top) {
                        Text(item.key)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(width: 96, alignment: .leading)
                        Text(item.value)
                            .font(.caption)
                            .textSelection(.enabled)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var parameterSummary: [(key: String, value: String)] {
        let decoded = (try? JSONDecoder().decode(
            [String: String].self,
            from: log.parameterSummaryData
        )) ?? [:]
        return decoded.sorted { $0.key.localizedCompare($1.key) == .orderedAscending }
    }
}

private struct AuditBadge: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption.weight(.semibold))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

#Preview {
    RootTabView()
        .modelContainer(for: DiarySchema.models, inMemory: true)
}
