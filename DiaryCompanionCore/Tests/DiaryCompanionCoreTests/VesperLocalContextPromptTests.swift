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

@Test func localContextPromptIncludesWorkoutProjectsAndHeartRate() {
    let date = Date(timeIntervalSince1970: 1_780_272_000)
    let prompt = VesperLocalContextPrompt.instruction(
        calendarSnapshots: [],
        healthSnapshots: [
            VesperHealthSummarySnapshot(
                date: date,
                stepCount: 8_888,
                activeEnergyKilocalories: 720,
                exerciseMinutes: 63,
                sleepMinutes: 420,
                sleepInBedMinutes: 460,
                workoutSummary: "自由训练 45 分钟；户外步行 18 分钟",
                averageHeartRate: 132,
                maxHeartRate: 176,
                sourceDescription: "HealthKit"
            ),
        ],
        now: date,
        timeZone: TimeZone(identifier: "Asia/Shanghai")!,
        calendar: Calendar(identifier: .gregorian),
        localeIdentifier: "zh_Hans"
    )

    #expect(prompt.contains("自由训练"))
    #expect(prompt.contains("户外步行"))
    #expect(prompt.contains("63 分钟"))
    #expect(prompt.contains("平均心率 132"))
    #expect(prompt.contains("最高心率 176"))
    #expect(prompt.contains("不要只看锻炼分钟是否为 0"))
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
