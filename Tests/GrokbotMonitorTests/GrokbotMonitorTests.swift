import Foundation
import Testing
@testable import GrokbotMonitor

@Test func base32DecodesPersistenceKeys() {
    #expect(String(data: Base32.decode("mzxw6")!, encoding: .utf8) == "foo")
}

@Test func activityClassifierFindsNamedWorkingBot() {
    let records = [
        AXRecord(role: "AXButton", title: nil, description: "Car rental is working", help: nil, valueText: nil, valueNumber: nil)
    ]
    let result = ActivityTextClassifier.classify(botName: "Car rental", records: records)
    #expect(result?.0 == .active)
}

@Test func activityClassifierPrioritizesWaiting() {
    let records = [
        AXRecord(role: "AXButton", title: "Hygglo Booker", description: "Waiting for you", help: nil, valueText: nil, valueNumber: nil),
        AXRecord(role: "AXStaticText", title: "Hygglo Booker is working", description: nil, help: nil, valueText: nil, valueNumber: nil)
    ]
    let result = ActivityTextClassifier.classify(botName: "Hygglo Booker", records: records)
    #expect(result?.0 == .needsYou)
}

@Test func usageParserKeepsExactPercentageAndLimits() {
    let now = Date(timeIntervalSince1970: 10)
    let records = [
        AXRecord(role: "AXProgressIndicator", title: nil, description: "Weekly usage limit: 4%", help: nil, valueText: nil, valueNumber: 4.136842),
        AXRecord(role: "AXStaticText", title: "Current plan: Pro", description: nil, help: nil, valueText: nil, valueNumber: nil),
        AXRecord(role: "AXStaticText", title: "Usage resets on Oct 10", description: nil, help: nil, valueText: nil, valueNumber: nil),
        AXRecord(role: "AXComboBox", title: nil, description: "On-demand monthly limit", help: nil, valueText: "None", valueNumber: nil)
    ]
    let result = UsageParser.parse(records: records, now: now)
    #expect(result?.percentUsed == 4.136842)
    #expect(result?.plan == "Pro")
    #expect(result?.resetDateDescription == "Oct 10")
    #expect(result?.onDemandLimit == "None")
    #expect(result?.capturedAt == now)
}
