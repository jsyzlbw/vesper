import Foundation
import Testing
import UserNotifications
@testable import DiaryCompanionCore

@Test func buildsCalendarNotificationRequest() throws {
    let date = try #require(
        Calendar(identifier: .gregorian).date(
            from: DateComponents(year: 2026, month: 6, day: 1, hour: 20, minute: 0)
        )
    )
    let request = ReminderRequestFactory().makeRequest(
        id: "medication-1",
        title: "吃药提醒",
        body: "记得吃药",
        fireDate: date
    )

    #expect(request.identifier == "medication-1")
    #expect(request.content.title == "吃药提醒")
    #expect(request.content.body == "记得吃药")

    let trigger = try #require(request.trigger as? UNCalendarNotificationTrigger)
    #expect(trigger.repeats == false)
    #expect(trigger.dateComponents.hour == 20)
    #expect(trigger.dateComponents.minute == 0)
}
