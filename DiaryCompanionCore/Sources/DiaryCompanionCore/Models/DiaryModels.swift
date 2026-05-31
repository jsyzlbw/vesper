import Foundation

public struct DiaryEntry: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public var date: Date
    public var content: String
    public var tags: [String]
    public var sourceMessageID: UUID?

    public init(
        id: UUID = UUID(),
        date: Date,
        content: String,
        tags: [String] = [],
        sourceMessageID: UUID? = nil
    ) {
        self.id = id
        self.date = date
        self.content = content
        self.tags = tags
        self.sourceMessageID = sourceMessageID
    }
}

public enum ToolExecutionResult: String, Codable, Equatable, Sendable {
    case success
    case failure
    case denied
}

public struct ToolAuditLog: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public let toolName: String
    public let parameterSummary: [String: String]
    public let decision: ToolPermissionDecision
    public let result: ToolExecutionResult
    public let createdAt: Date

    public init(
        id: UUID = UUID(),
        toolName: String,
        parameters: [String: String],
        decision: ToolPermissionDecision,
        result: ToolExecutionResult,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.toolName = toolName
        self.parameterSummary = Dictionary(
            uniqueKeysWithValues: parameters.map { key, value in
                let normalized = key.lowercased()
                let isSensitive = normalized.contains("apikey")
                    || normalized.contains("authorization")
                    || normalized.contains("token")
                    || normalized.contains("secret")
                return (key, isSensitive ? "<redacted>" : value)
            }
        )
        self.decision = decision
        self.result = result
        self.createdAt = createdAt
    }
}
