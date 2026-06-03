import DiaryCompanionCore
import SwiftUI

struct ReminderProposalCard: View {
    @Environment(\.vesperLocalization) private var localization
    let reminder: ReminderRecord
    let proposal: ReminderProposal?
    let action: (ReminderCardAction) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            VStack(spacing: 0) {
                detailRow(
                    title: localization.strings.schedulingMode,
                    value: schedulingModeText,
                    systemImage: "calendar.badge.clock"
                )
                Divider()
                detailRow(
                    title: localization.strings.eventTime,
                    value: scheduleText,
                    systemImage: "calendar"
                )
                Divider()
                detailRow(
                    title: localization.strings.recurrence,
                    value: recurrenceText,
                    systemImage: "arrow.trianglehead.2.clockwise"
                )
                Divider()
                detailRow(
                    title: localization.strings.eventDuration,
                    value: localization.strings.durationMinutes(reminder.durationMinutes),
                    systemImage: "hourglass"
                )
                Divider()
                detailRow(
                    title: localization.strings.systemNotification,
                    value: reminder.notificationEnabled ? localization.strings.on : localization.strings.off,
                    systemImage: "bell.badge"
                )
                if reminder.notificationEnabled {
                    Divider()
                    detailRow(
                        title: localization.strings.notificationTime,
                        value: outputTimeText(leadMinutes: reminder.notificationLeadMinutes),
                        systemImage: "bell"
                    )
                }
                Divider()
                detailRow(
                    title: localization.strings.realAlarm,
                    value: reminder.alarmEnabled ? localization.strings.on : localization.strings.off,
                    systemImage: "alarm"
                )
                if reminder.alarmEnabled {
                    Divider()
                    detailRow(
                        title: localization.strings.alarmTime,
                        value: outputTimeText(leadMinutes: reminder.alarmLeadMinutes),
                        systemImage: "alarm.waves.left.and.right"
                    )
                }
                Divider()
                detailRow(
                    title: localization.strings.addToCalendar,
                    value: reminder.calendarEnabled ? localization.strings.on : localization.strings.off,
                    systemImage: "calendar.badge.plus"
                )
            }
            .background(Color(.tertiarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))

            if !reminder.notes.isEmpty {
                editableButton {
                    Text(reminder.notes)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            actionButtons
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay {
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(Color.accentColor.opacity(0.18))
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "bell.and.waves.left.and.right.fill")
                .font(.title3)
                .foregroundStyle(Color.accentColor)
                .frame(width: 38, height: 38)
                .background(Color.accentColor.opacity(0.12))
                .clipShape(Circle())

            editableButton {
                VStack(alignment: .leading, spacing: 4) {
                    Text(statusTitle)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(statusColor)
                    Text(reminder.title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                }
            }
            Spacer()
        }
    }

    private func detailRow(
        title: String,
        value: String,
        systemImage: String
    ) -> some View {
        editableButton {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 20)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(value)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                }
                Spacer()
                if canEdit {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
        }
    }

    @ViewBuilder
    private func editableButton<Content: View>(
        @ViewBuilder content: () -> Content
    ) -> some View {
        if canEdit {
            Button {
                action(.edit)
            } label: {
                content()
            }
            .buttonStyle(.plain)
        } else {
            content()
        }
    }

    @ViewBuilder
    private var actionButtons: some View {
        switch status {
        case .pendingConfirmation:
            if needsAutomaticPlacement {
                Label(localization.strings.waitingForAutomaticPlacement, systemImage: "calendar.badge.clock")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.orange)
            } else {
                HStack {
                    Button(localization.strings.cancel, role: .cancel) {
                        action(.cancel)
                    }
                    Spacer()
                    Button(localization.strings.confirmCreation) {
                        action(.confirm)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        case .executing:
            HStack {
                ProgressView()
                Text(localization.strings.interruptedCreation)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button(localization.strings.recover) {
                    action(.recover)
                }
                .buttonStyle(.bordered)
            }
        case .scheduled:
            HStack {
                Label(localization.strings.created, systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Spacer()
                Button(localization.strings.cancelReminder, role: .destructive) {
                    action(.cancel)
                }
            }
            .font(.subheadline.weight(.medium))
        case .cancelled:
            HStack {
                Label(localization.strings.cancelled, systemImage: "xmark.circle")
                    .foregroundStyle(.secondary)
                Spacer()
                Button(localization.strings.restoreReminder) {
                    action(.recover)
                }
                .buttonStyle(.bordered)
            }
            .font(.subheadline.weight(.medium))
        case nil:
            Label(localization.strings.invalidReminderStatus, systemImage: "exclamationmark.triangle")
                .font(.subheadline)
                .foregroundStyle(.red)
        }
    }

    private var status: ReminderProposalStatus? {
        ReminderProposalStatus(rawValue: reminder.status)
    }

    private var needsAutomaticPlacement: Bool {
        reminder.schedulingMode == ReminderSchedulingMode.findFreeTime.rawValue
            && reminder.firstOccurrence == nil
    }

    private var canEdit: Bool {
        status == .pendingConfirmation
    }

    private var statusTitle: String {
        switch status {
        case .pendingConfirmation:
            localization.strings.suggestedReminder
        case .executing:
            localization.strings.creatingReminder
        case .scheduled:
            localization.strings.reminderCreated
        case .cancelled:
            localization.strings.reminderCancelled
        case nil:
            localization.strings.invalidReminderStatus
        }
    }

    private var statusColor: Color {
        switch status {
        case .scheduled:
            .green
        case .cancelled:
            .secondary
        case nil:
            .red
        default:
            .accentColor
        }
    }

    private var scheduleText: String {
        if let firstOccurrence = reminder.firstOccurrence {
            return firstOccurrence.formatted(
                Date.FormatStyle(date: .abbreviated, time: .shortened)
                    .locale(localization.locale)
            )
        }
        if let start = reminder.searchWindowStart,
           let end = reminder.searchWindowEnd {
            return localization.strings.automaticRange(
                start.formatted(
                    Date.FormatStyle(date: .abbreviated, time: .shortened)
                        .locale(localization.locale)
                ),
                end.formatted(
                    Date.FormatStyle(date: .omitted, time: .shortened)
                        .locale(localization.locale)
                )
            )
        }
        return localization.strings.waitingForTime
    }

    private var schedulingModeText: String {
        reminder.schedulingMode == ReminderSchedulingMode.findFreeTime.rawValue
            ? localization.strings.automaticScheduling
            : localization.strings.fixedTime
    }

    private func outputTimeText(leadMinutes: Int) -> String {
        guard let firstOccurrence = reminder.firstOccurrence else {
            return localization.strings.waitingForTime
        }
        let outputTime = Calendar.current.date(
            byAdding: .minute,
            value: -leadMinutes,
            to: firstOccurrence
        ) ?? firstOccurrence
        return localization.strings.outputTime(
            outputTime.formatted(
                Date.FormatStyle(date: .abbreviated, time: .shortened)
                    .locale(localization.locale)
            ),
            minutesBefore: leadMinutes
        )
    }

    private var recurrenceText: String {
        guard let proposal else {
            return reminder.repeats ? localization.strings.repeatingReminder : localization.strings.once
        }
        return recurrenceSummary(proposal.recurrence)
    }

    private func recurrenceSummary(_ rule: ReminderRecurrenceRule) -> String {
        switch rule {
        case .once:
            localization.strings.once
        case let .daily(interval, end):
            recurrenceSummary(base: localization.strings.daily, interval: interval, end: end)
        case let .weekly(interval, weekdays, end):
            recurrenceSummary(
                base: "\(localization.strings.weekly): \(weekdays.map(localization.strings.weekday).joined(separator: ", "))",
                interval: interval,
                end: end
            )
        case let .monthly(interval, day, end):
            recurrenceSummary(base: localization.strings.monthlyDay(day), interval: interval, end: end)
        case let .monthlyLastDay(interval, end):
            recurrenceSummary(base: localization.strings.monthlyLastDay, interval: interval, end: end)
        case let .yearly(interval, month, day, end):
            recurrenceSummary(base: "\(localization.strings.month(month)), \(localization.strings.day(day))", interval: interval, end: end)
        }
    }

    private func recurrenceSummary(
        base: String,
        interval: Int,
        end: ReminderRecurrenceEnd?
    ) -> String {
        var parts = [base]
        if interval > 1 {
            parts.append(localization.strings.interval(interval))
        }
        if case let .occurrenceCount(count) = end {
            parts.append(localization.strings.recurrenceOccurrences(count))
        }
        if case let .date(date) = end {
            parts.append(
                localization.strings.recurrenceUntil(
                    date.formatted(
                        Date.FormatStyle(date: .abbreviated, time: .omitted)
                            .locale(localization.locale)
                    )
                )
            )
        }
        return parts.joined(separator: localization.language == .simplifiedChinese ? "，" : ", ")
    }
}

enum ReminderCardAction {
    case edit
    case confirm
    case cancel
    case recover
}
