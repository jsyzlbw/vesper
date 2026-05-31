import Foundation
import Testing
@testable import DiaryCompanionCore

@Test func emptyBusyIntervalsReturnWindowStart() {
    let window = interval(9, 17)

    let slot = CalendarAvailabilityService().firstAvailableSlot(
        within: window,
        durationMinutes: 60,
        busyIntervals: []
    )

    #expect(slot == interval(9, 10))
}

@Test func overlappingBusyIntervalsAreMerged() {
    let slot = CalendarAvailabilityService().firstAvailableSlot(
        within: interval(9, 17),
        durationMinutes: 60,
        busyIntervals: [
            interval(9, 10),
            interval(9.5, 11),
            interval(13, 14),
        ]
    )

    #expect(slot == interval(11, 12))
}

@Test func touchingBusyIntervalsAreMerged() {
    let slot = CalendarAvailabilityService().firstAvailableSlot(
        within: interval(9, 17),
        durationMinutes: 60,
        busyIntervals: [
            interval(9, 10),
            interval(10, 11),
            interval(11, 12),
        ]
    )

    #expect(slot == interval(12, 13))
}

@Test func busyIntervalsAreClippedToWindow() {
    let slot = CalendarAvailabilityService().firstAvailableSlot(
        within: interval(9, 17),
        durationMinutes: 60,
        busyIntervals: [
            interval(8, 10),
            interval(16, 18),
            interval(18, 19),
        ]
    )

    #expect(slot == interval(10, 11))
}

@Test func trailingGapIsReturned() {
    let slot = CalendarAvailabilityService().firstAvailableSlot(
        within: interval(9, 17),
        durationMinutes: 60,
        busyIntervals: [
            interval(9, 12),
            interval(12.5, 16),
        ]
    )

    #expect(slot == interval(16, 17))
}

@Test func returnsNilWhenNoGapIsLongEnough() {
    let slot = CalendarAvailabilityService().firstAvailableSlot(
        within: interval(9, 17),
        durationMinutes: 60,
        busyIntervals: [
            interval(9, 9.5),
            interval(10, 10.5),
            interval(11, 17),
        ]
    )

    #expect(slot == nil)
}

@Test(arguments: [0, -1])
func rejectsNonPositiveDuration(durationMinutes: Int) {
    let slot = CalendarAvailabilityService().firstAvailableSlot(
        within: interval(9, 17),
        durationMinutes: durationMinutes,
        busyIntervals: []
    )

    #expect(slot == nil)
}

@Test func rejectsWindowShorterThanRequestedDuration() {
    let slot = CalendarAvailabilityService().firstAvailableSlot(
        within: interval(9, 9.5),
        durationMinutes: 60,
        busyIntervals: []
    )

    #expect(slot == nil)
}

@Test func earliestGapWinsDeterministically() {
    let slot = CalendarAvailabilityService().firstAvailableSlot(
        within: interval(9, 17),
        durationMinutes: 60,
        busyIntervals: [
            interval(9, 10),
            interval(10, 11),
            interval(13, 14),
        ]
    )

    #expect(slot == interval(11, 12))
}

@Test func unorderedBusyIntervalsAreSortedBeforeFindingGap() {
    let slot = CalendarAvailabilityService().firstAvailableSlot(
        within: interval(9, 17),
        durationMinutes: 60,
        busyIntervals: [
            interval(13, 14),
            interval(9.5, 11),
            interval(9, 10),
        ]
    )

    #expect(slot == interval(11, 12))
}

private func interval(_ startHour: Double, _ endHour: Double) -> DateInterval {
    DateInterval(
        start: Date(timeIntervalSince1970: startHour * 60 * 60),
        end: Date(timeIntervalSince1970: endHour * 60 * 60)
    )
}
