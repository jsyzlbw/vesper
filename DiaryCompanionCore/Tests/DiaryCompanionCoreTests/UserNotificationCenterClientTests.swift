import Foundation
import Testing
import UserNotifications
@testable import DiaryCompanionCore

@MainActor
@Test func notificationClientRequestsAlertAndSoundAuthorization() async throws {
    let center = NotificationCenterSpy()
    let client = UserNotificationCenterClient(center: center)

    #expect(try await client.requestAuthorization())
    #expect(center.authorizationOptions == [.alert, .sound])
}

@MainActor
@Test func notificationClientAddsEveryRequest() async throws {
    let center = NotificationCenterSpy()
    let client = UserNotificationCenterClient(center: center)
    let requests = ["one", "two"].map(makeNotificationRequest)

    try await client.add(requests)

    #expect(center.addedIdentifiers == ["one", "two"])
}

@MainActor
@Test func notificationClientRollsBackEarlierRequestsWhenBatchAddFails() async {
    let center = NotificationCenterSpy()
    center.addErrorAtIndex = 1
    let client = UserNotificationCenterClient(center: center)
    let requests = ["one", "two", "three"].map(makeNotificationRequest)

    await #expect(throws: NotificationCenterSpy.TestError.addFailed) {
        try await client.add(requests)
    }
    #expect(center.addedIdentifiers == ["one", "two"])
    #expect(center.removedIdentifierBatches == [["one"]])
}

@MainActor
private final class NotificationCenterSpy: UserNotificationCenter {
    enum TestError: Error {
        case addFailed
    }

    var authorizationOptions: UNAuthorizationOptions?
    var addedIdentifiers: [String] = []
    var removedIdentifierBatches: [[String]] = []
    var addErrorAtIndex: Int?

    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
        authorizationOptions = options
        return true
    }

    func add(_ request: UNNotificationRequest) async throws {
        addedIdentifiers.append(request.identifier)
        if addedIdentifiers.count - 1 == addErrorAtIndex {
            throw TestError.addFailed
        }
    }

    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {
        removedIdentifierBatches.append(identifiers)
    }
}

private func makeNotificationRequest(identifier: String) -> UNNotificationRequest {
    UNNotificationRequest(identifier: identifier, content: UNNotificationContent(), trigger: nil)
}
