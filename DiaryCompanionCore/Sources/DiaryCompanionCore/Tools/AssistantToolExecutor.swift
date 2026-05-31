import Foundation

public enum AssistantToolCall: Equatable, Sendable {
    case createDiaryEntry(
        date: Date,
        content: String,
        tags: [String],
        sourceMessageID: UUID?
    )
    case createTask(
        title: String,
        notes: String,
        dueAt: Date?,
        sourceMessageID: UUID?
    )

    public var tool: DiaryTool {
        switch self {
        case .createDiaryEntry:
            .createDiaryEntry
        case .createTask:
            .createTask
        }
    }

    public var parameterSummary: [String: String] {
        switch self {
        case let .createDiaryEntry(date, content, tags, sourceMessageID):
            [
                "date": date.ISO8601Format(),
                "content": content,
                "tags": tags.joined(separator: ", "),
                "sourceMessageID": sourceMessageID?.uuidString ?? "",
            ]
        case let .createTask(title, notes, dueAt, sourceMessageID):
            [
                "title": title,
                "notes": notes,
                "dueAt": dueAt?.ISO8601Format() ?? "",
                "sourceMessageID": sourceMessageID?.uuidString ?? "",
            ]
        }
    }
}

public enum AssistantToolExecutionOutcome: Equatable, Sendable {
    case executed
    case confirmationRequired
    case denied
}

@MainActor
public final class AssistantToolExecutor {
    private let repository: DiaryRepository
    private let policy: ToolPermissionPolicy

    public init(
        repository: DiaryRepository,
        policy: ToolPermissionPolicy
    ) {
        self.repository = repository
        self.policy = policy
    }

    public func execute(
        _ call: AssistantToolCall
    ) throws -> AssistantToolExecutionOutcome {
        let decision = policy.decision(for: call.tool)
        switch decision {
        case .allow:
            return try perform(call, decision: .allow)
        case .confirm:
            try saveAuditLog(
                for: call,
                decision: .confirm,
                result: .pendingConfirmation
            )
            return .confirmationRequired
        case .deny:
            try saveAuditLog(for: call, decision: .deny, result: .denied)
            return .denied
        }
    }

    public func executeConfirmed(
        _ call: AssistantToolCall
    ) throws -> AssistantToolExecutionOutcome {
        let decision = policy.decision(for: call.tool)
        guard decision != .deny else {
            try saveAuditLog(for: call, decision: .deny, result: .denied)
            return .denied
        }
        return try perform(call, decision: .confirm)
    }

    private func perform(
        _ call: AssistantToolCall,
        decision: ToolPermissionDecision
    ) throws -> AssistantToolExecutionOutcome {
        do {
            switch call {
            case let .createDiaryEntry(date, content, tags, sourceMessageID):
                try repository.createDiaryEntry(
                    date: date,
                    content: content,
                    tags: tags,
                    sourceMessageID: sourceMessageID
                )
            case let .createTask(title, notes, dueAt, sourceMessageID):
                try repository.createTask(
                    title: title,
                    notes: notes,
                    dueAt: dueAt,
                    sourceMessageID: sourceMessageID
                )
            }
            try saveAuditLog(for: call, decision: decision, result: .success)
            return .executed
        } catch {
            try? saveAuditLog(for: call, decision: decision, result: .failure)
            throw error
        }
    }

    private func saveAuditLog(
        for call: AssistantToolCall,
        decision: ToolPermissionDecision,
        result: ToolExecutionResult
    ) throws {
        try repository.saveAuditLog(
            ToolAuditLog(
                toolName: call.tool.rawValue,
                parameters: call.parameterSummary,
                decision: decision,
                result: result
            )
        )
    }
}
