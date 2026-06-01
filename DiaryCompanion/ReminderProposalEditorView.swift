import DiaryCompanionCore
import SwiftUI

struct ReminderProposalEditorView: View {
    let originalProposal: ReminderProposal
    let save: (ReminderProposal) async throws -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var draft: ReminderEditorDraft
    @State private var isSaving = false
    @State private var errorMessage: String?

    init(
        originalProposal: ReminderProposal,
        save: @escaping (ReminderProposal) async throws -> Void
    ) {
        self.originalProposal = originalProposal
        self.save = save
        _draft = State(
            initialValue: ReminderEditorDraft(
                proposal: ReminderProposalEditorSupport.preparedForEditing(
                    originalProposal
                )
            )
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                basicsSection
                schedulingSection
                recurrenceSection
                outputSection
                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("编辑提醒")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                    .disabled(isSaving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        Task {
                            await saveDraft()
                        }
                    }
                    .disabled(isSaving)
                }
            }
        }
    }

    private var basicsSection: some View {
        Section("提醒内容") {
            TextField("标题", text: $draft.title)
            TextField("备注", text: $draft.notes, axis: .vertical)
                .lineLimit(2...5)
            Stepper(
                "事件持续时间：\(draft.durationMinutes) 分钟",
                value: $draft.durationMinutes,
                in: 1...1_440,
                step: 5
            )
        }
    }

    private var schedulingSection: some View {
        Section("安排方式") {
            Picker("方式", selection: $draft.schedulingMode) {
                Text("固定时间").tag(ReminderSchedulingMode.fixed)
                Text("自动安排到空闲时间").tag(ReminderSchedulingMode.findFreeTime)
            }
            if draft.schedulingMode == .fixed {
                DatePicker(
                    "提醒时间",
                    selection: $draft.start,
                    displayedComponents: [.date, .hourAndMinute]
                )
            } else {
                DatePicker(
                    "范围开始",
                    selection: $draft.searchWindowStart,
                    displayedComponents: [.date, .hourAndMinute]
                )
                DatePicker(
                    "范围结束",
                    selection: $draft.searchWindowEnd,
                    displayedComponents: [.date, .hourAndMinute]
                )
                Text("保存后会读取所有可见日历，并选择最早可用时段。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var recurrenceSection: some View {
        Section("重复规则") {
            Picker("频率", selection: $draft.recurrenceKind) {
                ForEach(ReminderEditorRecurrenceKind.allCases) { kind in
                    Text(kind.title).tag(kind)
                }
            }
            if draft.recurrenceKind != .once {
                Stepper(
                    "间隔：\(draft.interval)",
                    value: $draft.interval,
                    in: 1...365
                )
                Toggle("限制重复次数", isOn: $draft.hasOccurrenceCount)
                if draft.hasOccurrenceCount {
                    Stepper(
                        "总次数：\(draft.occurrenceCount)",
                        value: $draft.occurrenceCount,
                        in: 1...10_000
                    )
                }
            }
            recurrenceSpecificFields
        }
    }

    @ViewBuilder
    private var recurrenceSpecificFields: some View {
        switch draft.recurrenceKind {
        case .once, .daily, .monthlyLastDay:
            EmptyView()
        case .weekly:
            ForEach(ReminderWeekday.allCases, id: \.rawValue) { weekday in
                Toggle(
                    ReminderEditorDraft.weekdayTitle(weekday),
                    isOn: weekdayBinding(weekday)
                )
            }
        case .monthly:
            Stepper("每月第 \(draft.monthlyDay) 日", value: $draft.monthlyDay, in: 1...31)
        case .yearly:
            Stepper("月份：\(draft.yearlyMonth)", value: $draft.yearlyMonth, in: 1...12)
            Stepper("日期：\(draft.yearlyDay)", value: $draft.yearlyDay, in: 1...31)
        }
    }

    private var outputSection: some View {
        Section("创建内容") {
            Toggle("系统通知（声音与震动）", isOn: $draft.notificationEnabled)
            Toggle("同步到日历", isOn: $draft.calendarEnabled)
        }
    }

    private func weekdayBinding(_ weekday: ReminderWeekday) -> Binding<Bool> {
        Binding(
            get: {
                draft.weekdays.contains(weekday)
            },
            set: { isSelected in
                if isSelected {
                    draft.weekdays.insert(weekday)
                } else {
                    draft.weekdays.remove(weekday)
                }
            }
        )
    }

    @MainActor
    private func saveDraft() async {
        isSaving = true
        defer {
            isSaving = false
        }
        do {
            let proposal = try draft.proposal()
            try await save(proposal)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private enum ReminderEditorRecurrenceKind: String, CaseIterable, Identifiable {
    case once
    case daily
    case weekly
    case monthly
    case monthlyLastDay
    case yearly

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .once:
            "仅一次"
        case .daily:
            "每天"
        case .weekly:
            "每周"
        case .monthly:
            "每月指定日期"
        case .monthlyLastDay:
            "每月最后一天"
        case .yearly:
            "每年"
        }
    }
}

private struct ReminderEditorDraft {
    var title: String
    var notes: String
    var start: Date
    var durationMinutes: Int
    var schedulingMode: ReminderSchedulingMode
    var searchWindowStart: Date
    var searchWindowEnd: Date
    var recurrenceKind: ReminderEditorRecurrenceKind
    var interval: Int
    var weekdays: Set<ReminderWeekday>
    var monthlyDay: Int
    var yearlyMonth: Int
    var yearlyDay: Int
    var hasOccurrenceCount: Bool
    var occurrenceCount: Int
    var preservedEndDate: Date?
    var notificationEnabled: Bool
    var calendarEnabled: Bool

    init(proposal: ReminderProposal, calendar: Calendar = .current) {
        let fallbackStart = proposal.start ?? Date()
        title = proposal.title
        notes = proposal.notes
        start = fallbackStart
        durationMinutes = proposal.durationMinutes
        schedulingMode = proposal.schedulingMode
        searchWindowStart = proposal.searchWindow?.start ?? fallbackStart
        searchWindowEnd = proposal.searchWindow?.end
            ?? calendar.date(byAdding: .hour, value: 1, to: fallbackStart)!
        notificationEnabled = proposal.notificationEnabled
        calendarEnabled = proposal.calendarEnabled

        switch proposal.recurrence {
        case .once:
            recurrenceKind = .once
            interval = 1
            weekdays = []
            monthlyDay = calendar.component(.day, from: fallbackStart)
            yearlyMonth = calendar.component(.month, from: fallbackStart)
            yearlyDay = calendar.component(.day, from: fallbackStart)
            preservedEndDate = nil
            occurrenceCount = 1
        case let .daily(value, end):
            recurrenceKind = .daily
            interval = value
            weekdays = []
            monthlyDay = 1
            yearlyMonth = 1
            yearlyDay = 1
            (preservedEndDate, occurrenceCount) = Self.endValues(end)
        case let .weekly(value, selectedWeekdays, end):
            recurrenceKind = .weekly
            interval = value
            weekdays = Set(selectedWeekdays)
            monthlyDay = 1
            yearlyMonth = 1
            yearlyDay = 1
            (preservedEndDate, occurrenceCount) = Self.endValues(end)
        case let .monthly(value, day, end):
            recurrenceKind = .monthly
            interval = value
            weekdays = []
            monthlyDay = day
            yearlyMonth = 1
            yearlyDay = 1
            (preservedEndDate, occurrenceCount) = Self.endValues(end)
        case let .monthlyLastDay(value, end):
            recurrenceKind = .monthlyLastDay
            interval = value
            weekdays = []
            monthlyDay = 1
            yearlyMonth = 1
            yearlyDay = 1
            (preservedEndDate, occurrenceCount) = Self.endValues(end)
        case let .yearly(value, month, day, end):
            recurrenceKind = .yearly
            interval = value
            weekdays = []
            monthlyDay = 1
            yearlyMonth = month
            yearlyDay = day
            (preservedEndDate, occurrenceCount) = Self.endValues(end)
        }
        hasOccurrenceCount = occurrenceCount > 0
    }

    func proposal() throws -> ReminderProposal {
        let proposal = ReminderProposal(
            title: title,
            notes: notes,
            start: schedulingMode == .fixed ? start : nil,
            durationMinutes: durationMinutes,
            recurrence: recurrence,
            schedulingMode: schedulingMode,
            searchWindow: schedulingMode == .findFreeTime
                ? ReminderSearchWindow(start: searchWindowStart, end: searchWindowEnd)
                : nil,
            notificationEnabled: notificationEnabled,
            calendarEnabled: calendarEnabled
        )
        try proposal.validate()
        return proposal
    }

    static func weekdayTitle(_ weekday: ReminderWeekday) -> String {
        ReminderProposalEditorSupport.recurrenceSummary(
            .weekly(interval: 1, weekdays: [weekday], end: nil)
        ).replacingOccurrences(of: "每周，", with: "")
    }

    private var recurrence: ReminderRecurrenceRule {
        let end: ReminderRecurrenceEnd? = hasOccurrenceCount
            ? .occurrenceCount(occurrenceCount)
            : preservedEndDate.map(ReminderRecurrenceEnd.date)
        switch recurrenceKind {
        case .once:
            return .once
        case .daily:
            return .daily(interval: interval, end: end)
        case .weekly:
            return .weekly(
                interval: interval,
                weekdays: ReminderWeekday.allCases.filter(weekdays.contains),
                end: end
            )
        case .monthly:
            return .monthly(interval: interval, day: monthlyDay, end: end)
        case .monthlyLastDay:
            return .monthlyLastDay(interval: interval, end: end)
        case .yearly:
            return .yearly(
                interval: interval,
                month: yearlyMonth,
                day: yearlyDay,
                end: end
            )
        }
    }

    private static func endValues(
        _ end: ReminderRecurrenceEnd?
    ) -> (Date?, Int) {
        switch end {
        case nil:
            (nil, 0)
        case let .date(date):
            (date, 0)
        case let .occurrenceCount(count):
            (nil, count)
        }
    }
}
