import Foundation

struct ReminderOccurrenceExpander {
    let calendar: Calendar

    func dates(
        recurrence: ReminderRecurrenceRule,
        anchor: Date,
        windowStart: Date,
        windowEnd: Date,
        leadMinutes: Int
    ) -> [Date] {
        guard let eventWindowEnd = calendar.date(
            byAdding: .minute,
            value: leadMinutes,
            to: windowEnd
        ) else {
            return []
        }

        var occurrences: [Date] = []
        var occurrenceCount = 0
        let end = recurrence.end

        func shouldContinue(_ occurrence: Date) -> Bool {
            if case let .date(endDate) = end, occurrence > endDate {
                return false
            }
            if case let .occurrenceCount(limit) = end,
               occurrenceCount >= limit {
                return false
            }
            return true
        }

        func record(_ occurrence: Date) -> Bool {
            guard shouldContinue(occurrence),
                  let fireDate = calendar.date(
                      byAdding: .minute,
                      value: -leadMinutes,
                      to: occurrence
                  ),
                  fireDate < windowEnd else {
                return false
            }
            occurrenceCount += 1
            if fireDate >= windowStart {
                occurrences.append(fireDate)
            }
            return true
        }

        switch recurrence {
        case .once:
            _ = record(anchor)
        case let .daily(interval, _):
            var offset = 0
            while let occurrence = calendar.date(
                byAdding: .day,
                value: offset,
                to: anchor
            ), record(occurrence) {
                offset += interval
            }
        case let .weekly(interval, weekdays, _):
            guard let anchorWeek = calendar.dateInterval(
                of: .weekOfYear,
                for: anchor
            )?.start else {
                return []
            }
            var weekOffset = 0
            weeklyLoop: while let week = calendar.date(
                byAdding: .weekOfYear,
                value: weekOffset,
                to: anchorWeek
            ), week < eventWindowEnd {
                let weeklyOccurrences = weekdays.compactMap { weekday in
                    weeklyOccurrence(
                        in: week,
                        weekday: weekday,
                        anchor: anchor
                    )
                }.filter { $0 >= anchor }.sorted()
                for occurrence in weeklyOccurrences {
                    guard record(occurrence) else {
                        break weeklyLoop
                    }
                }
                weekOffset += interval
            }
        case let .monthly(interval, day, _):
            var monthOffset = 0
            while let month = calendar.date(
                byAdding: .month,
                value: monthOffset,
                to: startOfMonth(containing: anchor)
            ), month < eventWindowEnd {
                if let occurrence = monthlyOccurrence(
                    in: month,
                    day: day,
                    anchor: anchor
                ), occurrence >= anchor, !record(occurrence) {
                    break
                }
                monthOffset += interval
            }
        case let .monthlyLastDay(interval, _):
            var monthOffset = 0
            while let month = calendar.date(
                byAdding: .month,
                value: monthOffset,
                to: startOfMonth(containing: anchor)
            ), month < eventWindowEnd {
                if let lastDay = calendar.range(of: .day, in: .month, for: month)?.last,
                   let occurrence = monthlyOccurrence(
                       in: month,
                       day: lastDay,
                       anchor: anchor
                   ),
                   occurrence >= anchor,
                   !record(occurrence) {
                    break
                }
                monthOffset += interval
            }
        case let .yearly(interval, month, day, _):
            let anchorYear = calendar.component(.year, from: anchor)
            var yearOffset = 0
            while let occurrenceYear = calendar.date(
                from: DateComponents(year: anchorYear + yearOffset)
            ), occurrenceYear < eventWindowEnd {
                if let occurrence = yearlyOccurrence(
                    year: anchorYear + yearOffset,
                    month: month,
                    day: day,
                    anchor: anchor
                ), occurrence >= anchor, !record(occurrence) {
                    break
                }
                yearOffset += interval
            }
        }

        return occurrences
    }

    private func weeklyOccurrence(
        in week: Date,
        weekday: ReminderWeekday,
        anchor: Date
    ) -> Date? {
        let anchorTime = calendar.dateComponents([.hour, .minute], from: anchor)
        var components = calendar.dateComponents(
            [.yearForWeekOfYear, .weekOfYear],
            from: week
        )
        components.weekday = weekday.rawValue
        components.hour = anchorTime.hour
        components.minute = anchorTime.minute
        return calendar.date(from: components)
    }

    private func startOfMonth(containing date: Date) -> Date {
        calendar.date(
            from: calendar.dateComponents([.year, .month], from: date)
        )!
    }

    private func monthlyOccurrence(in month: Date, day: Int, anchor: Date) -> Date? {
        let monthComponents = calendar.dateComponents([.year, .month], from: month)
        let anchorTime = calendar.dateComponents([.hour, .minute], from: anchor)
        var components = monthComponents
        components.day = day
        components.hour = anchorTime.hour
        components.minute = anchorTime.minute
        guard let occurrence = calendar.date(from: components) else {
            return nil
        }
        let resolved = calendar.dateComponents([.year, .month, .day], from: occurrence)
        guard resolved.year == components.year,
              resolved.month == components.month,
              resolved.day == components.day else {
            return nil
        }
        return occurrence
    }

    private func yearlyOccurrence(
        year: Int,
        month: Int,
        day: Int,
        anchor: Date
    ) -> Date? {
        let anchorTime = calendar.dateComponents([.hour, .minute], from: anchor)
        var components = DateComponents(year: year, month: month, day: day)
        components.hour = anchorTime.hour
        components.minute = anchorTime.minute
        guard let occurrence = calendar.date(from: components) else {
            return nil
        }
        let resolved = calendar.dateComponents([.year, .month, .day], from: occurrence)
        guard resolved.year == year,
              resolved.month == month,
              resolved.day == day else {
            return nil
        }
        return occurrence
    }
}

private extension ReminderRecurrenceRule {
    var end: ReminderRecurrenceEnd? {
        switch self {
        case .once:
            nil
        case let .daily(_, end),
             let .weekly(_, _, end),
             let .monthly(_, _, end),
             let .monthlyLastDay(_, end),
             let .yearly(_, _, _, end):
            end
        }
    }
}
