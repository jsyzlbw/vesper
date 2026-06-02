import Testing
@testable import DiaryCompanionCore

@Test func retriesWhenAlarmReplyAsksForConfirmationWithoutCard() {
    let policy = ReminderResponseRepairPolicy()

    #expect(policy.shouldRequestStructuredProposal(
        latestUserText: "设置一个15分钟后的闹钟，提醒我去吃饭",
        assistantText: "好的，我来为您安排一个15分钟后的闹钟。请确认是否创建此闹钟？",
        hasProposal: false
    ))
}

@Test func retriesWhenAlarmReplyClaimsSuccessWithoutCard() {
    let policy = ReminderResponseRepairPolicy()

    #expect(policy.shouldRequestStructuredProposal(
        latestUserText: "创建",
        assistantText: "好的，闹钟已成功创建！会准时响铃。",
        hasProposal: false
    ))
}

@Test func allowsClarifyingQuestionWithoutCard() {
    let policy = ReminderResponseRepairPolicy()

    #expect(!policy.shouldRequestStructuredProposal(
        latestUserText: "提醒我吃饭",
        assistantText: "你希望几点提醒？",
        hasProposal: false
    ))
}

@Test func neverRetriesCompletedProposal() {
    let policy = ReminderResponseRepairPolicy()

    #expect(!policy.shouldRequestStructuredProposal(
        latestUserText: "设置闹钟",
        assistantText: "请确认创建闹钟。",
        hasProposal: true
    ))
}
