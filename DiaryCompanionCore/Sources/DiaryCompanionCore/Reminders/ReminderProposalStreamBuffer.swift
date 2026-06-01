public struct ReminderProposalStreamBuffer: Sendable {
    public private(set) var rawText = ""
    public private(set) var visibleText = ""

    private var pendingText = ""
    private var isHidingEnvelope = false

    public init() {}

    public mutating func append(_ delta: String) {
        rawText.append(delta)
        guard !isHidingEnvelope else {
            return
        }

        pendingText.append(delta)
        let marker = ReminderProposalEnvelopeParser.startMarker
        if let markerRange = pendingText.range(of: marker) {
            visibleText.append(contentsOf: pendingText[..<markerRange.lowerBound])
            pendingText = ""
            isHidingEnvelope = true
            return
        }

        let heldSuffixLength = longestSuffixMatchingMarkerPrefix(
            in: pendingText,
            marker: marker
        )
        let flushEnd = pendingText.index(pendingText.endIndex, offsetBy: -heldSuffixLength)
        visibleText.append(contentsOf: pendingText[..<flushEnd])
        pendingText = String(pendingText[flushEnd...])
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
