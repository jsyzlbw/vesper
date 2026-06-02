#if canImport(AlarmKit)
@preconcurrency import AlarmKit
import DiaryCompanionCore
import Foundation
import SwiftUI

@available(iOS 26.0, *)
struct VesperAlarmMetadata: AlarmMetadata {
    let reminderID: UUID
}

@available(iOS 26.0, *)
final class AlarmKitAlarmClient: AlarmClient {
    private let manager = AlarmManager.shared

    func requestAuthorization() async throws -> Bool {
        try await manager.requestAuthorization() == .authorized
    }

    func schedule(
        reminderID: UUID,
        proposal: ReminderProposal,
        occurrences: [AlarmOccurrence]
    ) async throws {
        guard proposal.alarmEnabled else {
            return
        }

        let existingIDs = Set(try manager.alarms.map(\.id))
        var createdIDs: [UUID] = []

        do {
            for occurrence in occurrences where !existingIDs.contains(occurrence.identifier) {
                let configuration = AlarmManager.AlarmConfiguration<VesperAlarmMetadata>.alarm(
                    schedule: .fixed(occurrence.fireDate),
                    attributes: AlarmAttributes(
                        presentation: AlarmPresentation(
                            alert: alert(title: proposal.title)
                        ),
                        metadata: VesperAlarmMetadata(reminderID: reminderID),
                        tintColor: .accentColor
                    )
                )
                _ = try await manager.schedule(
                    id: occurrence.identifier,
                    configuration: configuration
                )
                createdIDs.append(occurrence.identifier)
            }
        } catch {
            for id in createdIDs {
                try? manager.cancel(id: id)
            }
            throw error
        }
    }

    func remove(ids: [String]) throws {
        let requestedIDs = Set(ids.compactMap(UUID.init(uuidString:)))
        guard !requestedIDs.isEmpty else {
            return
        }

        let existingIDs = Set(try manager.alarms.map(\.id))
        for id in requestedIDs where existingIDs.contains(id) {
            try manager.cancel(id: id)
        }
    }

    private func alert(title: String) -> AlarmPresentation.Alert {
        let localizedTitle = LocalizedStringResource(stringLiteral: title)
        if #available(iOS 26.1, *) {
            return .init(title: localizedTitle)
        }
        return .init(
            title: localizedTitle,
            stopButton: AlarmButton(
                text: "Stop",
                textColor: .white,
                systemImageName: "stop.fill"
            )
        )
    }
}
#endif
