import DiaryCompanionCore
import Foundation

#if canImport(AlarmKit)
@preconcurrency import AlarmKit
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
            var failedRollbackIDs: [String] = []
            for id in createdIDs {
                do {
                    try manager.cancel(id: id)
                } catch {
                    failedRollbackIDs.append(id.uuidString)
                }
            }
            if !failedRollbackIDs.isEmpty {
                throw AlarmClientError.rollbackFailed(failedRollbackIDs)
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

@MainActor
func makeAlarmClient() -> any AlarmClient {
#if canImport(AlarmKit)
    if #available(iOS 26.0, *) {
        return AlarmKitAlarmClient()
    }
#endif
    return UnavailableAlarmClient()
}

enum AlarmKitDebugProbe {
    @MainActor
    static func runIfRequested() async {
#if DEBUG && canImport(AlarmKit)
        guard CommandLine.arguments.contains("--alarmkit-smoke") else {
            return
        }
        guard #available(iOS 26.0, *) else {
            print("VESPER_ALARMKIT_SMOKE unsupported-ios")
            return
        }

        let seconds = smokeDelaySeconds
        let fireDate = Date().addingTimeInterval(seconds)
        let identifier = UUID()
        let proposal = ReminderProposal(
            title: "Vesper AlarmKit Smoke Test",
            notes: "Debug-only real-device AlarmKit probe.",
            start: fireDate,
            durationMinutes: 1,
            recurrence: .once,
            schedulingMode: .fixed,
            searchWindow: nil,
            notificationEnabled: false,
            alarmEnabled: true,
            alarmLeadMinutes: 0,
            calendarEnabled: false
        )
        let client = AlarmKitAlarmClient()

        do {
            let authorized = try await client.requestAuthorization()
            guard authorized else {
                print("VESPER_ALARMKIT_SMOKE authorization-denied")
                return
            }
            try await client.schedule(
                reminderID: identifier,
                proposal: proposal,
                occurrences: [
                    AlarmOccurrence(identifier: identifier, fireDate: fireDate),
                ]
            )
            let alarms = try AlarmManager.shared.alarms
            let registered = alarms.contains { $0.id == identifier }
            print(
                "VESPER_ALARMKIT_SMOKE registered=\(registered)"
                    + " id=\(identifier.uuidString)"
                    + " daemonCount=\(alarms.count)"
                    + " delaySeconds=\(Int(seconds))"
            )
        } catch {
            print("VESPER_ALARMKIT_SMOKE error=\(String(describing: error))")
        }
#endif
    }

    private static var smokeDelaySeconds: TimeInterval {
        guard let index = CommandLine.arguments.firstIndex(of: "--alarmkit-smoke"),
              CommandLine.arguments.indices.contains(index + 1),
              let value = TimeInterval(CommandLine.arguments[index + 1]),
              value > 0 else {
            return 90
        }
        return value
    }
}
