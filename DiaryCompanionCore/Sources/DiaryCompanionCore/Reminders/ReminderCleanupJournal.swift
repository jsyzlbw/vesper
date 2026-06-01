import Foundation

public struct ReminderCleanupJournalEntry: Codable, Equatable, Sendable {
    public var calendarReference: CalendarEventReference?
    public var notificationIdentifiers: [String]

    public init(
        calendarReference: CalendarEventReference?,
        notificationIdentifiers: [String]
    ) {
        self.calendarReference = calendarReference
        self.notificationIdentifiers = notificationIdentifiers
    }
}

@MainActor
public protocol ReminderCleanupJournaling: AnyObject {
    func save(reminderID: UUID, entry: ReminderCleanupJournalEntry) throws
    func load(reminderID: UUID) throws -> ReminderCleanupJournalEntry?
    func remove(reminderID: UUID) throws
}

@MainActor
public final class FileReminderCleanupJournal: ReminderCleanupJournaling {
    private let fileURL: URL
    private let fileManager: FileManager

    public convenience init() {
        self.init(fileURL: Self.defaultFileURL)
    }

    public init(fileURL: URL, fileManager: FileManager = .default) {
        self.fileURL = fileURL
        self.fileManager = fileManager
    }

    public func save(
        reminderID: UUID,
        entry: ReminderCleanupJournalEntry
    ) throws {
        var entries = try loadEntries()
        entries[reminderID.uuidString] = entry
        try write(entries)
    }

    public func load(reminderID: UUID) throws -> ReminderCleanupJournalEntry? {
        try loadEntries()[reminderID.uuidString]
    }

    public func remove(reminderID: UUID) throws {
        var entries = try loadEntries()
        entries.removeValue(forKey: reminderID.uuidString)
        try write(entries)
    }

    private func loadEntries() throws -> [String: ReminderCleanupJournalEntry] {
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return [:]
        }
        return try JSONDecoder().decode(
            [String: ReminderCleanupJournalEntry].self,
            from: Data(contentsOf: fileURL)
        )
    }

    private func write(_ entries: [String: ReminderCleanupJournalEntry]) throws {
        try fileManager.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try JSONEncoder().encode(entries).write(to: fileURL, options: .atomic)
    }

    static var defaultFileURL: URL {
        let baseURL = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? FileManager.default.temporaryDirectory
        return baseURL
            .appendingPathComponent("DiaryCompanion", isDirectory: true)
            .appendingPathComponent("reminder-cleanup-journal.json")
    }
}
