import DiaryCompanionCore
import EventKit
import Foundation
import HealthKit
import SwiftData
import UserNotifications

@MainActor
struct JournalAutomationService {
    let context: ModelContext
    let localization: VesperLocalizationContext

    func refresh() async {
        let repository = DiaryRepository(context: context)
        guard let settings = try? repository.journalSettings() else {
            return
        }

        await schedulePrompts(settings: settings)
        if settings.isCalendarImportEnabled {
            await importCalendarEvents(repository: repository)
        }
        if settings.isHealthImportEnabled {
            await importHealthSummaries(repository: repository)
        }
        await createDueJournalPrompts(repository: repository, settings: settings)
    }

    private func schedulePrompts(settings: JournalSettingsRecord) async {
        let center = UNUserNotificationCenter.current()
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        guard granted else {
            return
        }
        center.removePendingNotificationRequests(
            withIdentifiers: [
                Self.morningNotificationIdentifier,
                Self.eveningNotificationIdentifier,
            ]
        )

        var requests: [UNNotificationRequest] = []
        if settings.isMorningPromptEnabled {
            requests.append(
                notificationRequest(
                    identifier: Self.morningNotificationIdentifier,
                    hour: settings.morningHour,
                    minute: settings.morningMinute,
                    title: localization.strings.morningJournalTitle,
                    body: localization.strings.morningJournalNotificationBody
                )
            )
        }
        if settings.isEveningPromptEnabled {
            requests.append(
                notificationRequest(
                    identifier: Self.eveningNotificationIdentifier,
                    hour: settings.eveningHour,
                    minute: settings.eveningMinute,
                    title: localization.strings.eveningJournalTitle,
                    body: localization.strings.eveningJournalNotificationBody
                )
            )
        }

        for request in requests {
            try? await center.add(request)
        }
    }

    private func notificationRequest(
        identifier: String,
        hour: Int,
        minute: Int,
        title: String,
        body: String
    ) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: components,
            repeats: true
        )
        return UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )
    }

    private func importCalendarEvents(repository: DiaryRepository) async {
        let eventStore = EKEventStore()
        guard ((try? await eventStore.requestFullAccessToEvents()) ?? false) else {
            return
        }

        let now = Date()
        let calendar = Calendar.current
        guard let start = calendar.date(byAdding: .day, value: -7, to: now),
              let end = calendar.date(byAdding: .day, value: 21, to: now)
        else {
            return
        }
        let predicate = eventStore.predicateForEvents(
            withStart: start,
            end: end,
            calendars: eventStore.calendars(for: .event)
        )
        let events = eventStore.events(matching: predicate)
        for event in events {
            guard let identifier = event.eventIdentifier else {
                continue
            }
            _ = try? repository.upsertCalendarEventSnapshot(
                eventIdentifier: identifier,
                externalIdentifier: event.calendarItemExternalIdentifier,
                title: event.title ?? localization.strings.untitledCalendarEvent,
                notes: event.notes ?? "",
                startDate: event.startDate,
                endDate: event.endDate,
                calendarTitle: event.calendar.title,
                isAllDay: event.isAllDay
            )
        }
    }

    private func importHealthSummaries(repository: DiaryRepository) async {
        guard HKHealthStore.isHealthDataAvailable() else {
            return
        }
        let store = HKHealthStore()
        let reader = HealthSummaryReader(store: store)
        guard await reader.requestAuthorization() else {
            return
        }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        for offset in -7...0 {
            guard let date = calendar.date(byAdding: .day, value: offset, to: today),
                  let summary = await reader.summary(for: date)
            else {
                continue
            }
            _ = try? repository.upsertHealthDailySummary(
                date: date,
                stepCount: summary.stepCount,
                activeEnergyKilocalories: summary.activeEnergyKilocalories,
                exerciseMinutes: summary.exerciseMinutes,
                sleepMinutes: summary.sleepMinutes,
                sleepInBedMinutes: summary.sleepInBedMinutes,
                sourceDescription: summary.sourceDescription
            )
        }
    }

    private func createDueJournalPrompts(
        repository: DiaryRepository,
        settings: JournalSettingsRecord
    ) async {
        let now = Date()
        if settings.isMorningPromptEnabled,
           isNowPast(hour: settings.morningHour, minute: settings.morningMinute, on: now),
           settings.lastMorningPromptDate.map({ !Calendar.current.isDate($0, inSameDayAs: now) }) ?? true {
            createMorningPlan(repository: repository, settings: settings, now: now)
        }

        if settings.isEveningPromptEnabled,
           isNowPast(hour: settings.eveningHour, minute: settings.eveningMinute, on: now),
           settings.lastEveningPromptDate.map({ !Calendar.current.isDate($0, inSameDayAs: now) }) ?? true {
            createEveningReviewPrompt(repository: repository, settings: settings, now: now)
        }

        createWeeklySummaryIfNeeded(repository: repository, settings: settings, now: now)
    }

    private func createMorningPlan(
        repository: DiaryRepository,
        settings: JournalSettingsRecord,
        now: Date
    ) {
        let body = morningBody(repository: repository, date: now)
        _ = try? repository.upsertJournalRecord(
            kind: JournalKind.morningPlan.rawValue,
            date: now,
            title: localization.strings.morningJournalTitle,
            body: body
        )
        try? appendAssistantMessage(localization.strings.morningAssistantMessage(body))
        try? repository.saveJournalSettings {
            $0.lastMorningPromptDate = now
        }
    }

    private func createEveningReviewPrompt(
        repository: DiaryRepository,
        settings: JournalSettingsRecord,
        now: Date
    ) {
        let body = eveningBody(repository: repository, date: now)
        _ = try? repository.upsertJournalRecord(
            kind: JournalKind.eveningReview.rawValue,
            date: now,
            title: localization.strings.eveningJournalTitle,
            body: body
        )
        try? appendAssistantMessage(localization.strings.eveningAssistantMessage(body))
        try? repository.saveJournalSettings {
            $0.lastEveningPromptDate = now
        }
    }

    private func createWeeklySummaryIfNeeded(
        repository: DiaryRepository,
        settings: JournalSettingsRecord,
        now: Date
    ) {
        let calendar = Calendar.current
        guard calendar.component(.weekday, from: now) == calendar.firstWeekday else {
            return
        }
        if let lastWeeklySummaryDate = settings.lastWeeklySummaryDate,
           calendar.isDate(lastWeeklySummaryDate, equalTo: now, toGranularity: .weekOfYear) {
            return
        }

        let body = weeklyBody(repository: repository, now: now)
        _ = try? repository.upsertJournalRecord(
            kind: JournalKind.weeklySummary.rawValue,
            date: now,
            title: localization.strings.weeklyJournalTitle,
            body: body
        )
        try? repository.saveJournalSettings {
            $0.lastWeeklySummaryDate = now
        }
    }

    private func appendAssistantMessage(_ content: String) throws {
        let conversationRepository = ConversationRepository(context: context)
        let conversation = try conversationRepository.defaultConversation()
        try conversationRepository.createMessage(
            conversationID: conversation.id,
            role: .assistant,
            content: content
        )
    }

    private func morningBody(repository: DiaryRepository, date: Date) -> String {
        let events = dayEvents(repository: repository, date: date)
        let health = dayHealth(repository: repository, date: date)
        var lines = [localization.strings.todayScheduleHeader]
        if events.isEmpty {
            lines.append(localization.strings.noCalendarEventsToday)
        } else {
            lines.append(contentsOf: events.prefix(8).map(eventLine))
        }
        lines.append("")
        lines.append(localization.strings.healthSnapshotHeader)
        lines.append(health.map(healthLine) ?? localization.strings.noHealthDataYet)
        return lines.joined(separator: "\n")
    }

    private func eveningBody(repository: DiaryRepository, date: Date) -> String {
        let events = dayEvents(repository: repository, date: date)
        let health = dayHealth(repository: repository, date: date)
        var lines = [localization.strings.eveningReviewPrompt]
        if !events.isEmpty {
            lines.append("")
            lines.append(localization.strings.todayScheduleHeader)
            lines.append(contentsOf: events.prefix(8).map(eventLine))
        }
        if let health {
            lines.append("")
            lines.append(localization.strings.healthSnapshotHeader)
            lines.append(healthLine(health))
        }
        return lines.joined(separator: "\n")
    }

    private func weeklyBody(repository: DiaryRepository, now: Date) -> String {
        let calendar = Calendar.current
        let weekInterval = calendar.dateInterval(of: .weekOfYear, for: now)
        let start = weekInterval?.start ?? now.addingTimeInterval(-7 * 86_400)
        let end = weekInterval?.end ?? now
        let events = (try? repository.fetchCalendarEventSnapshots()) ?? []
        let eventCount = events.filter { $0.startDate >= start && $0.startDate < end }.count
        let health = ((try? repository.fetchHealthDailySummaries()) ?? [])
            .filter { $0.date >= start && $0.date < end }
        let steps = health.reduce(0) { $0 + $1.stepCount }
        let sleepMinutes = health.reduce(0) { $0 + $1.sleepMinutes }
        return localization.strings.weeklyJournalBody(
            eventCount: eventCount,
            stepCount: Int(steps.rounded()),
            sleepHours: sleepMinutes / 60
        )
    }

    private func dayEvents(
        repository: DiaryRepository,
        date: Date
    ) -> [CalendarEventSnapshotRecord] {
        ((try? repository.fetchCalendarEventSnapshots()) ?? [])
            .filter { Calendar.current.isDate($0.startDate, inSameDayAs: date) }
            .sorted { $0.startDate < $1.startDate }
    }

    private func dayHealth(
        repository: DiaryRepository,
        date: Date
    ) -> HealthDailySummaryRecord? {
        ((try? repository.fetchHealthDailySummaries()) ?? [])
            .first { Calendar.current.isDate($0.date, inSameDayAs: date) }
    }

    private func eventLine(_ event: CalendarEventSnapshotRecord) -> String {
        if event.isAllDay {
            return "• \(event.title) · \(localization.strings.allDay)"
        }
        let start = event.startDate.formatted(
            Date.FormatStyle(date: .omitted, time: .shortened)
                .locale(localization.locale)
        )
        let end = event.endDate.formatted(
            Date.FormatStyle(date: .omitted, time: .shortened)
                .locale(localization.locale)
        )
        return "• \(start)-\(end) \(event.title)"
    }

    private func healthLine(_ health: HealthDailySummaryRecord) -> String {
        localization.strings.healthSummaryLine(
            steps: Int(health.stepCount.rounded()),
            energy: Int(health.activeEnergyKilocalories.rounded()),
            exerciseMinutes: Int(health.exerciseMinutes.rounded()),
            sleepHours: health.sleepMinutes / 60
        )
    }

    private func isNowPast(hour: Int, minute: Int, on date: Date) -> Bool {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: date)
        components.hour = hour
        components.minute = minute
        guard let target = Calendar.current.date(from: components) else {
            return false
        }
        return date >= target
    }

    private static let morningNotificationIdentifier = "vesper.journal.morning"
    private static let eveningNotificationIdentifier = "vesper.journal.evening"
}

enum JournalKind: String {
    case morningPlan
    case eveningReview
    case weeklySummary
}

private struct HealthSummary {
    var stepCount: Double
    var activeEnergyKilocalories: Double
    var exerciseMinutes: Double
    var sleepMinutes: Double
    var sleepInBedMinutes: Double
    var sourceDescription: String
}

private struct HealthSummaryReader {
    let store: HKHealthStore

    func requestAuthorization() async -> Bool {
        var readTypes: Set<HKObjectType> = []
        if let steps = HKQuantityType.quantityType(forIdentifier: .stepCount) {
            readTypes.insert(steps)
        }
        if let energy = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) {
            readTypes.insert(energy)
        }
        if let exercise = HKQuantityType.quantityType(forIdentifier: .appleExerciseTime) {
            readTypes.insert(exercise)
        }
        if let sleep = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) {
            readTypes.insert(sleep)
        }
        return await withCheckedContinuation { continuation in
            store.requestAuthorization(toShare: [], read: readTypes) { success, _ in
                continuation.resume(returning: success)
            }
        }
    }

    func summary(for date: Date) async -> HealthSummary? {
        let interval = dayInterval(for: date)
        async let steps = quantitySum(.stepCount, unit: .count(), interval: interval)
        async let energy = quantitySum(.activeEnergyBurned, unit: .kilocalorie(), interval: interval)
        async let exercise = quantitySum(.appleExerciseTime, unit: .minute(), interval: interval)
        async let sleep = sleepSummary(interval: interval)
        let values = await (steps, energy, exercise, sleep)
        return HealthSummary(
            stepCount: values.0,
            activeEnergyKilocalories: values.1,
            exerciseMinutes: values.2,
            sleepMinutes: values.3.asleep,
            sleepInBedMinutes: values.3.inBed,
            sourceDescription: "HealthKit"
        )
    }

    private func quantitySum(
        _ identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        interval: DateInterval
    ) async -> Double {
        guard let type = HKQuantityType.quantityType(forIdentifier: identifier) else {
            return 0
        }
        let predicate = HKQuery.predicateForSamples(
            withStart: interval.start,
            end: interval.end,
            options: .strictStartDate
        )
        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, statistics, _ in
                continuation.resume(
                    returning: statistics?.sumQuantity()?.doubleValue(for: unit) ?? 0
                )
            }
            store.execute(query)
        }
    }

    private func sleepSummary(interval: DateInterval) async -> (asleep: Double, inBed: Double) {
        guard let type = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
            return (0, 0)
        }
        let predicate = HKQuery.predicateForSamples(
            withStart: interval.start,
            end: interval.end,
            options: .strictStartDate
        )
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, _ in
                let categorySamples = samples as? [HKCategorySample] ?? []
                var asleep = 0.0
                var inBed = 0.0
                for sample in categorySamples {
                    let duration = sample.endDate.timeIntervalSince(sample.startDate) / 60
                    if sample.value == HKCategoryValueSleepAnalysis.inBed.rawValue {
                        inBed += duration
                    } else if sample.value != HKCategoryValueSleepAnalysis.awake.rawValue {
                        asleep += duration
                    }
                }
                continuation.resume(returning: (asleep, inBed))
            }
            store.execute(query)
        }
    }

    private func dayInterval(for date: Date) -> DateInterval {
        let start = Calendar.current.startOfDay(for: date)
        let end = Calendar.current.date(byAdding: .day, value: 1, to: start)
            ?? start.addingTimeInterval(86_400)
        return DateInterval(start: start, end: end)
    }
}
