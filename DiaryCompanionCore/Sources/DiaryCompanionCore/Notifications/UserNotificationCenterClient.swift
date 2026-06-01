import UserNotifications

@MainActor
public protocol ReminderNotificationClient: AnyObject {
    func requestAuthorization() async throws -> Bool
    func add(_ requests: [UNNotificationRequest]) async throws
    func removePendingRequests(withIdentifiers identifiers: [String])
}

@MainActor
public protocol UserNotificationCenter: AnyObject {
    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool
    func add(_ request: UNNotificationRequest) async throws
    func removePendingNotificationRequests(withIdentifiers identifiers: [String])
}

extension UNUserNotificationCenter: UserNotificationCenter {}

@MainActor
public final class UserNotificationCenterClient: ReminderNotificationClient {
    private let center: UserNotificationCenter

    public init(center: UserNotificationCenter = UNUserNotificationCenter.current()) {
        self.center = center
    }

    public func requestAuthorization() async throws -> Bool {
        try await center.requestAuthorization(options: [.alert, .sound])
    }

    public func add(_ requests: [UNNotificationRequest]) async throws {
        var addedIdentifiers: [String] = []
        do {
            for request in requests {
                try await center.add(request)
                addedIdentifiers.append(request.identifier)
            }
        } catch {
            center.removePendingNotificationRequests(withIdentifiers: addedIdentifiers)
            throw error
        }
    }

    public func removePendingRequests(withIdentifiers identifiers: [String]) {
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }
}
