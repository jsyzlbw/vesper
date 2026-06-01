import Foundation

public struct CalendarAvailabilityService: Sendable {
    public init() {}

    public func firstAvailableSlot(
        within searchWindow: DateInterval,
        durationMinutes: Int,
        busyIntervals: [DateInterval]
    ) -> DateInterval? {
        firstAvailableSlot(
            within: searchWindow,
            durationMinutes: durationMinutes,
            busyIntervals: busyIntervals,
            matchingStart: { _ in true }
        )
    }

    public func firstAvailableSlot(
        within searchWindow: DateInterval,
        durationMinutes: Int,
        busyIntervals: [DateInterval],
        stepMinutes: Int = 15,
        matchingStart: (Date) -> Bool
    ) -> DateInterval? {
        guard durationMinutes > 0, stepMinutes > 0 else {
            return nil
        }

        let duration = TimeInterval(durationMinutes) * 60
        guard searchWindow.duration >= duration else {
            return nil
        }

        let clippedIntervals = busyIntervals
            .compactMap { $0.intersection(with: searchWindow) }
            .sorted {
                if $0.start == $1.start {
                    return $0.end < $1.end
                }
                return $0.start < $1.start
            }

        var cursor = searchWindow.start
        for interval in merged(clippedIntervals) {
            if let slot = firstMatchingSlot(
                from: cursor,
                through: interval.start,
                duration: duration,
                stepMinutes: stepMinutes,
                matchingStart: matchingStart
            ) {
                return slot
            }
            if interval.end > cursor {
                cursor = interval.end
            }
        }

        return firstMatchingSlot(
            from: cursor,
            through: searchWindow.end,
            duration: duration,
            stepMinutes: stepMinutes,
            matchingStart: matchingStart
        )
    }

    private func firstMatchingSlot(
        from start: Date,
        through end: Date,
        duration: TimeInterval,
        stepMinutes: Int,
        matchingStart: (Date) -> Bool
    ) -> DateInterval? {
        let step = TimeInterval(stepMinutes) * 60
        var candidate = start
        while end.timeIntervalSince(candidate) >= duration {
            if matchingStart(candidate) {
                return DateInterval(start: candidate, duration: duration)
            }
            candidate.addTimeInterval(step)
        }
        return nil
    }

    private func merged(_ intervals: [DateInterval]) -> [DateInterval] {
        intervals.reduce(into: []) { result, interval in
            guard let last = result.last else {
                result.append(interval)
                return
            }
            guard interval.start <= last.end else {
                result.append(interval)
                return
            }

            result[result.count - 1] = DateInterval(
                start: last.start,
                end: max(last.end, interval.end)
            )
        }
    }
}
