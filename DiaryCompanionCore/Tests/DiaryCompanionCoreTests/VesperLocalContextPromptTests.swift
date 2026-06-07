import Foundation
import Testing
@testable import DiaryCompanionCore

@Test func healthSnapshotUsesInBedAsSleepFallback() {
    let date = Date(timeIntervalSince1970: 1_780_272_000)
    let snapshot = VesperHealthSummarySnapshot(
        date: date,
        stepCount: 6_768,
        activeEnergyKilocalories: 648,
        exerciseMinutes: 0,
        sleepMinutes: 0,
        sleepInBedMinutes: 500,
        sourceDescription: "HealthKit"
    )

    #expect(snapshot.effectiveSleepMinutes == 500)
    #expect(snapshot.sleepSourceNote.contains("卧床"))
    #expect(snapshot.sleepSourceNote.contains("asleep"))
}

@Test func localContextPromptIncludesCalendarHealthAndCaveats() {
    let timeZone = TimeZone(identifier: "Asia/Shanghai")!
    let calendar = Calendar(identifier: .gregorian)
    let start = Date(timeIntervalSince1970: 1_780_272_000)
    let end = start.addingTimeInterval(3_600)
    let prompt = VesperLocalContextPrompt.instruction(
        calendarSnapshots: [
            VesperCalendarEventSnapshot(
                title: "深度学习",
                startDate: start,
                endDate: end,
                calendarTitle: "课业",
                isAllDay: false
            ),
        ],
        healthSnapshots: [
            VesperHealthSummarySnapshot(
                date: start,
                stepCount: 6_768,
                activeEnergyKilocalories: 648,
                exerciseMinutes: 0,
                sleepMinutes: 0,
                sleepInBedMinutes: 500,
                sourceDescription: "HealthKit"
            ),
        ],
        now: start,
        timeZone: timeZone,
        calendar: calendar,
        localeIdentifier: "zh_Hans"
    )

    #expect(prompt.contains("本地上下文"))
    #expect(prompt.contains("深度学习"))
    #expect(prompt.contains("课业"))
    #expect(prompt.contains("6768 步"))
    #expect(prompt.contains("648 千卡"))
    #expect(prompt.contains("约 8.3 小时"))
    #expect(prompt.contains("卧床记录估算"))
    #expect(prompt.contains("不要声称读取失败"))
    #expect(prompt.contains("不要编造"))
}

@Test func localContextPromptHandlesMissingHealthExplicitly() {
    let prompt = VesperLocalContextPrompt.instruction(
        calendarSnapshots: [],
        healthSnapshots: [],
        now: Date(timeIntervalSince1970: 1_780_272_000),
        timeZone: TimeZone(identifier: "Asia/Shanghai")!,
        calendar: Calendar(identifier: .gregorian),
        localeIdentifier: "zh_Hans"
    )

    #expect(prompt.contains("最近没有本地 Health 摘要"))
    #expect(prompt.contains("不要编造睡眠、运动或步数"))
}
