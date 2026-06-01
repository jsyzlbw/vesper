import Testing
@testable import DiaryCompanionCore

@Test func reminderProposalStreamBufferStreamsOrdinaryText() {
    var buffer = ReminderProposalStreamBuffer()

    buffer.append("先帮你")
    buffer.append("整理一下。")

    #expect(buffer.rawText == "先帮你整理一下。")
    #expect(buffer.visibleText == "先帮你整理一下。")
}

@Test func reminderProposalStreamBufferHidesCompleteEnvelope() {
    var buffer = ReminderProposalStreamBuffer()

    buffer.append("""
    已整理。
    \(ReminderProposalEnvelopeParser.startMarker)
    {"title":"Review"}
    \(ReminderProposalEnvelopeParser.endMarker)
    """)

    #expect(buffer.rawText.contains(#"{"title":"Review"}"#))
    #expect(buffer.visibleText == "已整理。\n")
}

@Test func reminderProposalStreamBufferHidesSplitStartMarkerWithoutFlashingPrefix() {
    var buffer = ReminderProposalStreamBuffer()

    buffer.append("已整理。[[DIARY_REM")
    #expect(buffer.visibleText == "已整理。")

    buffer.append("INDER_PROPOSAL]]{\"title\":\"Review\"}")
    #expect(buffer.visibleText == "已整理。")

    buffer.append(ReminderProposalEnvelopeParser.endMarker)
    #expect(buffer.visibleText == "已整理。")
}

@Test func reminderProposalStreamBufferRestoresMarkerLikeTextThatDoesNotMatch() {
    var buffer = ReminderProposalStreamBuffer()

    buffer.append("普通文本 [[DIARY_REM")
    #expect(buffer.visibleText == "普通文本 ")

    buffer.append("ARK")
    #expect(buffer.visibleText == "普通文本 [[DIARY_REMARK")
}

@Test func reminderProposalStreamBufferKeepsFollowingTextHiddenAfterEnvelopeStarts() {
    var buffer = ReminderProposalStreamBuffer()

    buffer.append(ReminderProposalEnvelopeParser.startMarker)
    buffer.append(#"{"title":"Review"}"#)
    buffer.append(ReminderProposalEnvelopeParser.endMarker)
    buffer.append("不应显示")

    #expect(buffer.visibleText.isEmpty)
}
