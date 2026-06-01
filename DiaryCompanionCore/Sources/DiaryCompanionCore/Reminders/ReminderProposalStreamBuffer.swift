public struct ReminderProposalStreamBuffer: Sendable {
    public private(set) var rawText = ""
    public private(set) var visibleText = ""

    public init() {}

    public mutating func append(_ delta: String) {
        rawText.append(delta)
        visibleText = makeVisibleText(flushIncompleteMarkerPrefix: false)
    }

    public mutating func finish() {
        visibleText = makeVisibleText(flushIncompleteMarkerPrefix: true)
    }

    private func makeVisibleText(flushIncompleteMarkerPrefix: Bool) -> String {
        let startMarker = ReminderProposalEnvelopeParser.startMarker
        let endMarker = ReminderProposalEnvelopeParser.endMarker
        var remaining = rawText[...]
        var result = ""

        while let startRange = remaining.range(of: startMarker) {
            result.append(contentsOf: remaining[..<startRange.lowerBound])
            let envelope = remaining[startRange.upperBound...]
            guard let endRange = envelope.range(of: endMarker) else {
                return result
            }
            remaining = envelope[endRange.upperBound...]
        }

        result.append(contentsOf: remaining)
        guard !flushIncompleteMarkerPrefix else {
            return result
        }

        let heldSuffixLength = longestSuffixMatchingMarkerPrefix(
            in: result,
            marker: startMarker
        )
        return String(result.dropLast(heldSuffixLength))
    }

    private func longestSuffixMatchingMarkerPrefix(
        in text: String,
        marker: String
    ) -> Int {
        let maximumLength = min(text.count, marker.count - 1)
        for length in stride(from: maximumLength, through: 1, by: -1) {
            if text.hasSuffix(marker.prefix(length)) {
                return length
            }
        }
        return 0
    }
}
