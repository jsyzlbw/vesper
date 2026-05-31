import Testing
@testable import DiaryCompanionCore

@Test func parsesOpenAICompatibleTextDelta() throws {
    let parser = OpenAICompatibleSSEParser()

    let event = try parser.parse(
        line: #"data: {"choices":[{"delta":{"content":"你好"}}]}"#
    )

    #expect(event == .textDelta("你好"))
}

@Test func parsesDeepSeekReasoningDelta() throws {
    let parser = OpenAICompatibleSSEParser()

    let event = try parser.parse(
        line: #"data: {"choices":[{"delta":{"reasoning_content":"先整理信息"}}]}"#
    )

    #expect(event == .reasoningDelta("先整理信息"))
}

@Test func parsesDoneMarker() throws {
    let parser = OpenAICompatibleSSEParser()

    #expect(try parser.parse(line: "data: [DONE]") == .done)
}

@Test func ignoresSSEControlLinesAndUsageOnlyChunks() throws {
    let parser = OpenAICompatibleSSEParser()

    #expect(try parser.parse(line: "") == nil)
    #expect(try parser.parse(line: ": keep-alive") == nil)
    #expect(
        try parser.parse(
            line: #"data: {"choices":[],"usage":{"total_tokens":42}}"#
        ) == nil
    )
}

@Test func rejectsMalformedJSONChunk() {
    let parser = OpenAICompatibleSSEParser()

    #expect(throws: ProviderStreamError.invalidEventData) {
        try parser.parse(line: "data: {not-json}")
    }
}
