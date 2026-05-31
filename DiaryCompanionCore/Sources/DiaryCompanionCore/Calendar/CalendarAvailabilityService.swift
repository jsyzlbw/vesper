import Foundation

public struct CalendarAvailabilityService: Sendable {
    public init() {}

    public func firstAvailableSlot(
        within searchWindow: DateInterval,
        durationMinutes: Int,
        busyIntervals: [DateInterval]
    ) -> DateInterval? {
        guard durationMinutes > 0 else {
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
            if interval.start.timeIntervalSince(cursor) >= duration {
                return DateInterval(start: cursor, duration: duration)
            }
            if interval.end > cursor {
                cursor = interval.end
            }
        }

        guard searchWindow.end.timeIntervalSince(cursor) >= duration else {
            return nil
        }
        return DateInterval(start: cursor, duration: duration)
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
