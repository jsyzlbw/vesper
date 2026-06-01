import DiaryCompanionCore
import SwiftUI

struct ReminderProposalCard: View {
    let reminder: ReminderRecord
    let proposal: ReminderProposal?
    let action: (ReminderCardAction) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            VStack(spacing: 0) {
                detailRow(
                    title: "安排方式",
                    value: schedulingModeText,
                    systemImage: "calendar.badge.clock"
                )
                Divider()
                detailRow(
                    title: "提醒时间",
                    value: scheduleText,
                    systemImage: "bell"
                )
                Divider()
                detailRow(
                    title: "重复规则",
                    value: recurrenceText,
                    systemImage: "arrow.trianglehead.2.clockwise"
                )
                Divider()
                detailRow(
                    title: "事件持续时间",
                    value: "\(reminder.durationMinutes) 分钟",
                    systemImage: "hourglass"
                )
                Divider()
                detailRow(
                    title: "系统通知",
                    value: reminder.notificationEnabled ? "开启" : "关闭",
                    systemImage: "bell.badge"
                )
                Divider()
                detailRow(
                    title: "同步到日历",
                    value: reminder.calendarEnabled ? "开启" : "关闭",
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
                Label("正在等待自动排期", systemImage: "calendar.badge.clock")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.orange)
            } else {
                HStack {
                    Button("取消", role: .cancel) {
                        action(.cancel)
                    }
                    Spacer()
                    Button("确认创建") {
                        action(.confirm)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        case .executing:
            HStack {
                ProgressView()
                Text("创建被中断，可恢复后重试")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("恢复") {
                    action(.recover)
                }
                .buttonStyle(.bordered)
            }
        case .scheduled:
            HStack {
                Label("已创建", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Spacer()
                Button("取消提醒", role: .destructive) {
                    action(.cancel)
                }
            }
            .font(.subheadline.weight(.medium))
        case .cancelled:
            Label("已取消", systemImage: "xmark.circle")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        case nil:
            Label("提醒状态异常", systemImage: "exclamationmark.triangle")
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
            "AI 建议创建提醒"
        case .executing:
            "正在创建提醒"
        case .scheduled:
            "提醒已创建"
        case .cancelled:
            "提醒已取消"
        case nil:
            "提醒状态异常"
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
                date: .abbreviated,
                time: .shortened
            )
        }
        if let start = reminder.searchWindowStart,
           let end = reminder.searchWindowEnd {
            return "自动安排：\(start.formatted(date: .abbreviated, time: .shortened)) - \(end.formatted(date: .omitted, time: .shortened))"
        }
        return "等待补充时间"
    }

    private var schedulingModeText: String {
        reminder.schedulingMode == ReminderSchedulingMode.findFreeTime.rawValue
            ? "自动安排到空闲时间"
            : "固定时间"
    }

    private var recurrenceText: String {
        guard let proposal else {
            return reminder.repeats ? "重复提醒" : "仅一次"
        }
        return ReminderProposalEditorSupport.recurrenceSummary(proposal.recurrence)
    }
}

enum ReminderCardAction {
    case edit
    case confirm
    case cancel
    case recover
}
