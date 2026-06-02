import DiaryCompanionCore
import SwiftUI

struct ReminderProposalEditorView: View {
    let originalProposal: ReminderProposal
    let save: (ReminderProposal) async throws -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.vesperLocalization) private var localization
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
            .navigationTitle(localization.strings.editReminder)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(localization.strings.cancel) {
                        dismiss()
                    }
                    .disabled(isSaving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(localization.strings.save) {
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
        Section(localization.strings.reminderContent) {
            TextField(localization.strings.title, text: $draft.title)
            TextField(localization.strings.notes, text: $draft.notes, axis: .vertical)
                .lineLimit(2...5)
            Stepper(
                localization.strings.durationStepper(draft.durationMinutes),
                value: $draft.durationMinutes,
                in: 1...1_440,
                step: 5
            )
        }
    }

    private var schedulingSection: some View {
        Section(localization.strings.schedulingMode) {
            Picker(localization.strings.schedulingMode, selection: $draft.schedulingMode) {
                Text(localization.strings.fixedTime).tag(ReminderSchedulingMode.fixed)
                Text(localization.strings.automaticScheduling).tag(ReminderSchedulingMode.findFreeTime)
            }
            if draft.schedulingMode == .fixed {
                DatePicker(
                    localization.strings.reminderTime,
                    selection: $draft.start,
                    displayedComponents: [.date, .hourAndMinute]
                )
            } else {
                DatePicker(
                    localization.strings.rangeStart,
                    selection: $draft.searchWindowStart,
                    displayedComponents: [.date, .hourAndMinute]
                )
                DatePicker(
                    localization.strings.rangeEnd,
                    selection: $draft.searchWindowEnd,
                    displayedComponents: [.date, .hourAndMinute]
                )
                Text(localization.strings.automaticSchedulingFooter)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var recurrenceSection: some View {
        Section(localization.strings.recurrence) {
            Picker(localization.strings.frequency, selection: $draft.recurrenceKind) {
                ForEach(ReminderEditorRecurrenceKind.allCases) { kind in
                    Text(kind.title(using: localization.strings)).tag(kind)
                }
            }
            if draft.recurrenceKind != .once {
                Stepper(
                    localization.strings.interval(draft.interval),
                    value: $draft.interval,
                    in: 1...365
                )
                Toggle(localization.strings.limitOccurrences, isOn: $draft.hasOccurrenceCount)
                if draft.hasOccurrenceCount {
                    Stepper(
                        localization.strings.totalOccurrences(draft.occurrenceCount),
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
                    localization.strings.weekday(weekday),
                    isOn: weekdayBinding(weekday)
                )
            }
        case .monthly:
            Stepper(localization.strings.monthlyDay(draft.monthlyDay), value: $draft.monthlyDay, in: 1...31)
        case .yearly:
            Stepper(localization.strings.month(draft.yearlyMonth), value: $draft.yearlyMonth, in: 1...12)
            Stepper(localization.strings.day(draft.yearlyDay), value: $draft.yearlyDay, in: 1...31)
        }
    }

    private var outputSection: some View {
        Section(localization.strings.createOutputs) {
            Toggle(localization.strings.soundAndVibration, isOn: $draft.notificationEnabled)
            if draft.notificationEnabled {
                Stepper(
                    localization.strings.minutesBeforeEvent(draft.notificationLeadMinutes),
                    value: $draft.notificationLeadMinutes,
                    in: 0...10_080,
                    step: 5
                )
            }
            Toggle(localization.strings.realAlarm, isOn: $draft.alarmEnabled)
            if draft.alarmEnabled {
                Stepper(
                    localization.strings.alarmMinutesBeforeEvent(draft.alarmLeadMinutes),
                    value: $draft.alarmLeadMinutes,
                    in: 0...10_080,
                    step: 5
                )
                Text(localization.strings.realAlarmIOS26Footer)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Toggle(localization.strings.addToCalendar, isOn: $draft.calendarEnabled)
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
            if let error = error as? ReminderProposalValidationError {
                errorMessage = error.localizedDescription(language: localization.language)
            } else if let error = error as? ReminderAutoSchedulingError {
                errorMessage = error.localizedDescription(language: localization.language)
            } else {
                errorMessage = error.localizedDescription
            }
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

    func title(using strings: VesperStrings) -> String {
        switch self {
        case .once:
            strings.once
        case .daily:
            strings.daily
        case .weekly:
            strings.weekly
        case .monthly:
            strings.monthly
        case .monthlyLastDay:
            strings.monthlyLastDay
        case .yearly:
            strings.yearly
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
    var notificationLeadMinutes: Int
    var alarmEnabled: Bool
    var alarmLeadMinutes: Int
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
        notificationLeadMinutes = proposal.notificationLeadMinutes
        alarmEnabled = proposal.alarmEnabled
        alarmLeadMinutes = proposal.alarmLeadMinutes
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
            notificationLeadMinutes: notificationLeadMinutes,
            alarmEnabled: alarmEnabled,
            alarmLeadMinutes: alarmLeadMinutes,
            calendarEnabled: calendarEnabled
        )
        try proposal.validate()
        return proposal
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
