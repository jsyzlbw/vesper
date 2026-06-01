import DiaryCompanionCore
import SwiftUI

struct ReminderProposalCard: View {
    let reminder: ReminderRecord
    let action: (ReminderCardAction) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            VStack(alignment: .leading, spacing: 9) {
                Label(scheduleText, systemImage: "calendar")
                Label(recurrenceText, systemImage: "arrow.trianglehead.2.clockwise")
                Label("\(reminder.durationMinutes) 分钟", systemImage: "clock")
                if reminder.notificationEnabled {
                    Label("系统通知：声音与震动", systemImage: "bell.badge")
                }
                if reminder.calendarEnabled {
                    Label("同步到日历", systemImage: "calendar.badge.plus")
                }
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)

            if !reminder.notes.isEmpty {
                Text(reminder.notes)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
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

            VStack(alignment: .leading, spacing: 4) {
                Text(statusTitle)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(statusColor)
                Text(reminder.title)
                    .font(.headline)
            }
            Spacer()
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

    private var recurrenceText: String {
        reminder.repeats ? "重复提醒" : "仅一次"
    }
}

enum ReminderCardAction {
    case confirm
    case cancel
    case recover
}
