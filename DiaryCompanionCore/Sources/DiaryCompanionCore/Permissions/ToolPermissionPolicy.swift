import Foundation

public enum ToolCapability: String, Codable, CaseIterable, Sendable {
    case diary
    case task
    case reminder
    case weight
    case meal
    case medication
    case summary
}

public enum ToolPermissionMode: String, Codable, CaseIterable, Sendable {
    case automatic
    case confirm
    case denied
}

public enum ToolPermissionDecision: String, Codable, Equatable, Sendable {
    case allow
    case confirm
    case deny
}

public enum DiaryTool: String, Codable, CaseIterable, Sendable {
    case createDiaryEntry
    case updateDiaryEntry
    case deleteDiaryEntry
    case recordWeight
    case recordMeal
    case updateMedication
    case createTask
    case completeTask
    case scheduleReminder
    case generateDailySummary

    public var capability: ToolCapability {
        switch self {
        case .createDiaryEntry, .updateDiaryEntry, .deleteDiaryEntry: .diary
        case .recordWeight: .weight
        case .recordMeal: .meal
        case .updateMedication: .medication
        case .createTask, .completeTask: .task
        case .scheduleReminder: .reminder
        case .generateDailySummary: .summary
        }
    }

    public var isHighRisk: Bool {
        self == .deleteDiaryEntry
    }
}

public struct ToolPermissionPolicy: Codable, Equatable, Sendable {
    public var capabilityModes: [ToolCapability: ToolPermissionMode]

    public init(
        capabilityModes: [ToolCapability: ToolPermissionMode] = [:]
    ) {
        self.capabilityModes = capabilityModes
    }

    public func decision(for tool: DiaryTool) -> ToolPermissionDecision {
        let mode = capabilityModes[tool.capability] ?? .confirm
        if mode == .denied {
            return .deny
        }
        if tool.isHighRisk || tool == .scheduleReminder {
            return .confirm
        }
        return mode == .automatic ? .allow : .confirm
    }
}
