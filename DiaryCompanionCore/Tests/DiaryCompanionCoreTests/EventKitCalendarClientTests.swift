import EventKit
import Foundation
import Testing
@testable import DiaryCompanionCore

@Test func freeEventIsNotBusy() {
    let interval = EventKitCalendarClient.interval(
        start: date(10),
        end: date(11),
        availability: .free,
        within: window
    )

    #expect(interval == nil)
}

@Test func eventWithoutStartIsNotBusy() {
    let interval = EventKitCalendarClient.interval(
        start: nil,
        end: date(11),
        availability: .busy,
        within: window
    )

    #expect(interval == nil)
}

@Test func eventWithoutEndIsNotBusy() {
    let interval = EventKitCalendarClient.interval(
        start: date(10),
        end: nil,
        availability: .busy,
        within: window
    )

    #expect(interval == nil)
}

@Test func reverseEventIntervalIsNotBusy() {
    let interval = EventKitCalendarClient.interval(
        start: date(11),
        end: date(10),
        availability: .busy,
        within: window
    )

    #expect(interval == nil)
}

@Test func zeroLengthEventIntervalIsNotBusy() {
    let interval = EventKitCalendarClient.interval(
        start: date(10),
        end: date(10),
        availability: .busy,
        within: window
    )

    #expect(interval == nil)
}

@Test func busyEventIsClippedToSearchWindow() {
    let interval = EventKitCalendarClient.interval(
        start: date(8),
        end: date(10),
        availability: .busy,
        within: window
    )

    #expect(interval == DateInterval(start: date(9), end: date(10)))
}

@Test func eventOutsideSearchWindowIsNotBusy() {
    let interval = EventKitCalendarClient.interval(
        start: date(7),
        end: date(8),
        availability: .busy,
        within: window
    )

    #expect(interval == nil)
}

@Test func eventTouchingSearchWindowEdgeIsNotBusy() {
    let interval = EventKitCalendarClient.interval(
        start: date(8),
        end: date(9),
        availability: .busy,
        within: window
    )

    #expect(interval == nil)
}

@Test func removalSpanCoversFutureRecurringEvents() {
    #expect(
        EventKitCalendarClient.removalSpan(hasRecurrenceRules: true)
            == .futureEvents
    )
}

@Test func removalSpanOnlyCoversSingleNonRecurringEvent() {
    #expect(
        EventKitCalendarClient.removalSpan(hasRecurrenceRules: false)
            == .thisEvent
    )
}

@Test func eventReferenceNormalizesEmptyExternalIdentifier() {
    let reference = CalendarEventReference(
        eventIdentifier: "event-1",
        externalIdentifier: ""
    )

    #expect(reference.externalIdentifier == nil)
}

@Test func eventLookupPrefersPrimaryIdentifier() throws {
    #expect(
        try EventKitCalendarClient.eventLookupResolution(
            primaryExists: true,
            externalIdentifier: "external-1",
            externalCandidatesCount: 2
        ) == .primary
    )
}

@Test func eventLookupUsesUniqueExternalIdentifierFallback() throws {
    #expect(
        try EventKitCalendarClient.eventLookupResolution(
            primaryExists: false,
            externalIdentifier: "external-1",
            externalCandidatesCount: 1
        ) == .externalCandidate
    )
}

@Test func eventLookupWithoutFallbackIsIdempotent() throws {
    #expect(
        try EventKitCalendarClient.eventLookupResolution(
            eventIdentifier: "event-1",
            primaryExists: false,
            externalIdentifier: nil,
            externalCandidatesCount: 0
        ) == .notFound
    )
}

@Test func eventLookupWithoutExternalMatchIsIdempotent() throws {
    #expect(
        try EventKitCalendarClient.eventLookupResolution(
            eventIdentifier: "event-1",
            primaryExists: false,
            externalIdentifier: "external-1",
            externalCandidatesCount: 0
        ) == .notFound
    )
}

@Test func eventLookupWithMultipleFallbackMatchesThrowsAmbiguousError() {
    #expect(
        throws: EventKitCalendarClientError.ambiguousExternalIdentifier("external-1")
    ) {
        try EventKitCalendarClient.eventLookupResolution(
            eventIdentifier: "event-1",
            primaryExists: false,
            externalIdentifier: "external-1",
            externalCandidatesCount: 2
        )
    }
}

private let window = DateInterval(start: date(9), end: date(17))

private func date(_ hour: Double) -> Date {
    Date(timeIntervalSince1970: hour * 60 * 60)
}
