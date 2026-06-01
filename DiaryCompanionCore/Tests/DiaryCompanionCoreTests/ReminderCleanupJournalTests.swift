import Foundation
import Testing
@testable import DiaryCompanionCore

@MainActor
@Test func cleanupJournalRoundTripsAndRemovesEntry() throws {
    let fileURL = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
        .appendingPathComponent("journal.json")
    let journal = FileReminderCleanupJournal(fileURL: fileURL)
    let reminderID = UUID()
    let entry = ReminderCleanupJournalEntry(
        calendarReference: CalendarEventReference(
            eventIdentifier: "event-1",
            externalIdentifier: "external-1"
        ),
        notificationIdentifiers: ["notification-1", "notification-2"]
    )

    try journal.save(reminderID: reminderID, entry: entry)
    #expect(try journal.load(reminderID: reminderID) == entry)

    try journal.remove(reminderID: reminderID)
    #expect(try journal.load(reminderID: reminderID) == nil)
}

@MainActor
@Test func cleanupJournalKeepsEntriesForOtherReminders() throws {
    let fileURL = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
        .appendingPathComponent("journal.json")
    let journal = FileReminderCleanupJournal(fileURL: fileURL)
    let firstID = UUID()
    let secondID = UUID()
    let secondEntry = ReminderCleanupJournalEntry(
        calendarReference: nil,
        notificationIdentifiers: ["notification-2"]
    )

    try journal.save(
        reminderID: firstID,
        entry: ReminderCleanupJournalEntry(
            calendarReference: nil,
            notificationIdentifiers: ["notification-1"]
        )
    )
    try journal.save(reminderID: secondID, entry: secondEntry)
    try journal.remove(reminderID: firstID)

    #expect(try journal.load(reminderID: secondID) == secondEntry)
}
