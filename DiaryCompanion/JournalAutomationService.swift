import DiaryCompanionCore
import EventKit
import Foundation
import HealthKit
import SwiftData
import UserNotifications

#if canImport(AlarmKit)
@preconcurrency import AlarmKit
import SwiftUI
#endif

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
        await scheduleEscalationAlarms(settings: settings)
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
                Self.weeklyNotificationIdentifier,
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
        if settings.isWeeklySummaryEnabled {
            requests.append(
                weeklyNotificationRequest(
                    identifier: Self.weeklyNotificationIdentifier,
                    weekday: settings.weeklySummaryWeekday,
                    hour: settings.weeklySummaryHour,
                    minute: settings.weeklySummaryMinute,
                    title: localization.strings.weeklyJournalTitle,
                    body: localization.strings.weeklyJournalNotificationBody
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

    private func weeklyNotificationRequest(
        identifier: String,
        weekday: Int,
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
        components.weekday = weekday
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

    private func scheduleEscalationAlarms(settings: JournalSettingsRecord) async {
#if canImport(AlarmKit)
        guard #available(iOS 26.0, *) else {
            return
        }
        let scheduler = JournalEscalationAlarmScheduler(localization: localization)
        await scheduler.refresh(settings: settings)
#endif
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
        guard settings.isWeeklySummaryEnabled,
              isWeeklyTimeDue(settings: settings, now: now) else {
            return
        }
        let calendar = Calendar.current
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
        try? appendAssistantMessage(localization.strings.weeklyAssistantMessage(body))
        try? repository.saveJournalSettings {
            $0.lastWeeklySummaryDate = now
        }
    }

    private func appendAssistantMessage(_ content: String) throws {
        let conversationRepository = ConversationRepository(context: context)
        let conversation = try conversationRepository.dailyConversation()
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
        let exerciseMinutes = health.reduce(0) { $0 + $1.exerciseMinutes }
        let dayCount = max(health.count, 1)
        return localization.strings.weeklyJournalBody(
            eventCount: eventCount,
            stepCount: Int(steps.rounded()),
            sleepHours: sleepMinutes / 60,
            averageSleepHours: sleepMinutes / 60 / Double(dayCount),
            exerciseMinutes: Int(exerciseMinutes.rounded())
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

    private func isWeeklyTimeDue(settings: JournalSettingsRecord, now: Date) -> Bool {
        let calendar = Calendar.current
        guard calendar.component(.weekday, from: now) == settings.weeklySummaryWeekday else {
            return false
        }
        return isNowPast(
            hour: settings.weeklySummaryHour,
            minute: settings.weeklySummaryMinute,
            on: now
        )
    }

    private static let morningNotificationIdentifier = "vesper.journal.morning"
    private static let eveningNotificationIdentifier = "vesper.journal.evening"
    private static let weeklyNotificationIdentifier = "vesper.journal.weekly"
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

#if canImport(AlarmKit)
@available(iOS 26.0, *)
@MainActor
private struct JournalEscalationAlarmScheduler {
    let localization: VesperLocalizationContext
    private let manager = AlarmManager.shared

    func refresh(settings: JournalSettingsRecord) async {
        guard ((try? await manager.requestAuthorization()) == .authorized) else {
            return
        }

        let identifiers = allCandidateIdentifiers(settings: settings)
        remove(ids: identifiers)

        var alarms: [(id: UUID, title: String, date: Date)] = []
        if settings.isMorningPromptEnabled,
           settings.isMorningEscalationAlarmEnabled {
            alarms.append(
                contentsOf: escalationAlarms(
                    seed: "morning",
                    title: localization.strings.morningJournalTitle,
                    hour: settings.morningHour,
                    minute: settings.morningMinute,
                    delayMinutes: settings.escalationDelayMinutes
                )
            )
        }
        if settings.isEveningPromptEnabled,
           settings.isEveningEscalationAlarmEnabled {
            alarms.append(
                contentsOf: escalationAlarms(
                    seed: "evening",
                    title: localization.strings.eveningJournalTitle,
                    hour: settings.eveningHour,
                    minute: settings.eveningMinute,
                    delayMinutes: settings.escalationDelayMinutes
                )
            )
        }

        for alarm in alarms {
            let configuration = AlarmManager.AlarmConfiguration<VesperAlarmMetadata>.alarm(
                schedule: .fixed(alarm.date),
                attributes: AlarmAttributes(
                    presentation: AlarmPresentation(
                        alert: alert(title: alarm.title)
                    ),
                    metadata: VesperAlarmMetadata(reminderID: alarm.id),
                    tintColor: .accentColor
                )
            )
            _ = try? await manager.schedule(id: alarm.id, configuration: configuration)
        }
    }

    private func escalationAlarms(
        seed: String,
        title: String,
        hour: Int,
        minute: Int,
        delayMinutes: Int
    ) -> [(id: UUID, title: String, date: Date)] {
        let calendar = Calendar.current
        let now = Date()
        let today = calendar.startOfDay(for: now)
        let safeDelay = min(max(delayMinutes, 1), 180)
        return (0..<30).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: offset, to: today),
                  let promptDate = promptDate(day: day, hour: hour, minute: minute),
                  let alarmDate = calendar.date(
                    byAdding: .minute,
                    value: safeDelay,
                    to: promptDate
                  )
            else {
                return nil
            }
            if offset == 0, now >= promptDate {
                return nil
            }
            guard alarmDate > now else {
                return nil
            }
            return (
                id: stableIdentifier(seed: "vesper.journal.\(seed).\(dateKey(day))"),
                title: title,
                date: alarmDate
            )
        }
    }

    private func allCandidateIdentifiers(settings: JournalSettingsRecord) -> [UUID] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return (-1..<45).flatMap { offset -> [UUID] in
            guard let day = calendar.date(byAdding: .day, value: offset, to: today) else {
                return []
            }
            return [
                stableIdentifier(seed: "vesper.journal.morning.\(dateKey(day))"),
                stableIdentifier(seed: "vesper.journal.evening.\(dateKey(day))"),
            ]
        }
    }

    private func remove(ids: [UUID]) {
        let existingIDs = (try? Set(manager.alarms.map(\.id))) ?? []
        for id in ids where existingIDs.contains(id) {
            try? manager.cancel(id: id)
        }
    }

    private func promptDate(day: Date, hour: Int, minute: Int) -> Date? {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: day)
        components.hour = hour
        components.minute = minute
        return Calendar.current.date(from: components)
    }

    private func dateKey(_ date: Date) -> String {
        let components = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return "\(components.year ?? 0)-\(components.month ?? 0)-\(components.day ?? 0)"
    }

    private func stableIdentifier(seed: String) -> UUID {
        let bytes = Array(seed.utf8)
        let first = fnv1a64(bytes, offset: 0xcbf29ce484222325)
        let second = fnv1a64(bytes.reversed(), offset: 0x84222325cbf29ce4)
        var uuidBytes = withUnsafeBytes(of: (first.bigEndian, second.bigEndian)) {
            Array($0)
        }
        uuidBytes[6] = (uuidBytes[6] & 0x0f) | 0x80
        uuidBytes[8] = (uuidBytes[8] & 0x3f) | 0x80
        return UUID(uuid: (
            uuidBytes[0], uuidBytes[1], uuidBytes[2], uuidBytes[3],
            uuidBytes[4], uuidBytes[5], uuidBytes[6], uuidBytes[7],
            uuidBytes[8], uuidBytes[9], uuidBytes[10], uuidBytes[11],
            uuidBytes[12], uuidBytes[13], uuidBytes[14], uuidBytes[15]
        ))
    }

    private func fnv1a64<S: Sequence>(
        _ bytes: S,
        offset: UInt64
    ) -> UInt64 where S.Element == UInt8 {
        bytes.reduce(offset) { hash, byte in
            (hash ^ UInt64(byte)) &* 0x100000001b3
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
