import Foundation
import Testing
@testable import GrokbotMonitor

@Test func base32DecodesPersistenceKeys() {
    #expect(String(data: Base32.decode("mzxw6")!, encoding: .utf8) == "foo")
}

@Test func activityClassifierFindsNamedWorkingBot() {
    let records = [
        AXRecord(role: "AXButton", title: nil, description: "Car rental is working", help: nil, valueText: nil, valueNumber: nil, frame: nil)
    ]
    let now = Date()
    let result = ActivityTextClassifier.classify(botName: "Car rental", activityDate: now, records: records, now: now)
    #expect(result?.0 == .active)
}

@Test func activityClassifierPrioritizesWaiting() {
    let records = [
        AXRecord(role: "AXButton", title: "Hygglo Booker", description: "Waiting for you", help: nil, valueText: nil, valueNumber: nil, frame: nil),
        AXRecord(role: "AXStaticText", title: "Hygglo Booker is working", description: nil, help: nil, valueText: nil, valueNumber: nil, frame: nil)
    ]
    let now = Date()
    let result = ActivityTextClassifier.classify(botName: "Hygglo Booker", activityDate: now, records: records, now: now)
    #expect(result?.0 == .needsYou)
}

@Test func activityClassifierRejectsStaleTranscriptStatus() {
    let now = Date()
    let records = [
        AXRecord(role: "AXStaticText", title: "Hygglo Booker Sending that to Anna now.", description: nil, help: nil, valueText: nil, valueNumber: nil, frame: CGRect(x: 400, y: 200, width: 300, height: 30))
    ]
    let result = ActivityTextClassifier.classify(
        botName: "Hygglo Booker",
        activityDate: now.addingTimeInterval(-8 * 60 * 60),
        records: records,
        now: now
    )
    #expect(result == nil)
}

@Test func usageParserKeepsExactPercentageAndLimits() {
    let now = Date(timeIntervalSince1970: 10)
    let records = [
        AXRecord(role: "AXProgressIndicator", title: nil, description: "Weekly usage limit: 4%", help: nil, valueText: nil, valueNumber: 4.136842, frame: nil),
        AXRecord(role: "AXStaticText", title: "Current plan: Pro", description: nil, help: nil, valueText: nil, valueNumber: nil, frame: nil),
        AXRecord(role: "AXStaticText", title: "Usage resets on Oct 10", description: nil, help: nil, valueText: nil, valueNumber: nil, frame: nil),
        AXRecord(role: "AXComboBox", title: nil, description: "On-demand monthly limit", help: nil, valueText: "None", valueNumber: nil, frame: nil)
    ]
    let result = UsageParser.parse(records: records, now: now)
    #expect(result?.percentUsed == 4.136842)
    #expect(result?.plan == "Pro")
    #expect(result?.resetDateDescription == "Oct 10")
    #expect(result?.onDemandLimit == "None")
    #expect(result?.capturedAt == now)
}

@Test func usageParserReadsCompactAccountMenu() {
    let records = [
        AXRecord(role: "AXGroup", title: nil, description: "Weekly usage 4%", help: nil, valueText: nil, valueNumber: nil, frame: nil)
    ]
    #expect(UsageParser.parse(records: records)?.percentUsed == 4)
}
