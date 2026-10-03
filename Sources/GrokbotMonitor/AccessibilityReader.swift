import AppKit
import ApplicationServices
import Foundation

struct AXRecord: Equatable, Sendable {
    let role: String
    let title: String?
    let description: String?
    let help: String?
    let valueText: String?
    let valueNumber: Double?
    let frame: CGRect?

    var combinedText: String {
        [title, description, help, valueText].compactMap { $0 }.joined(separator: " · ")
    }
}

enum ActivityTextClassifier {
    private static let waitingWords = ["waiting for you", "needs you", "needs your", "approval required", "answer needed"]
    private static let failureWords = [" failed", "error", "couldn’t", "could not"]
    private static let activeWords = [
        " is working", "working", "thinking", "searching", "browsing", "reading", "writing",
        "coding", "generating", "running commands", "on its computer", "on your computer",
        "sending", "computing", "controlling"
    ]

    static func classify(
        botName: String,
        activityDate: Date?,
        records: [AXRecord],
        now: Date = Date()
    ) -> (BotState, String?)? {
        let name = botName.lowercased()
        let matching = records.filter {
            $0.combinedText.lowercased().contains(name) && ["AXButton", "AXGroup", "AXStaticText"].contains($0.role)
        }

        if let record = matching.first(where: { record in
            waitingWords.contains(where: record.combinedText.lowercased().contains)
        }) { return (.needsYou, cleanDetail(record.combinedText, name: botName)) }
        if let record = matching.first(where: { record in
            failureWords.contains(where: record.combinedText.lowercased().contains)
        }) { return (.failed, cleanDetail(record.combinedText, name: botName)) }

        let activeMatches = matching.filter { record in
            activeWords.contains(where: record.combinedText.lowercased().contains)
        }
        guard !activeMatches.isEmpty, let activityDate else { return nil }

        // Grok Bot leaves old activity prose mounted in the transcript. Strong
        // signals must be buttons or live in the narrow bot sidebar. Elsewhere,
        // text is accepted only while the roster timestamp is very recent.
        let age = now.timeIntervalSince(activityDate)
        guard age >= -60, age < 15 * 60 else { return nil }
        let windowFrame = records.first(where: { $0.role == "AXWindow" })?.frame
        if let strong = activeMatches.first(where: { record in
            record.role == "AXButton" || isInSidebar(record.frame, windowFrame: windowFrame)
        }) {
            return (.active, cleanDetail(strong.combinedText, name: botName))
        }
        if age < 90, let recent = activeMatches.first {
            return (.active, cleanDetail(recent.combinedText, name: botName))
        }
        return nil
    }

    private static func isInSidebar(_ frame: CGRect?, windowFrame: CGRect?) -> Bool {
        guard let frame, let windowFrame, frame.width > 0 else { return false }
        let sidebarEdge = windowFrame.minX + min(240, windowFrame.width * 0.22)
        return frame.midX <= sidebarEdge
    }

    private static func cleanDetail(_ text: String, name: String) -> String? {
        let pieces = text.components(separatedBy: " · ")
            .filter { $0.caseInsensitiveCompare(name) != .orderedSame }
        return pieces.first { !$0.isEmpty && $0.count < 100 }
    }
}

enum UsageParser {
    static func parse(records: [AXRecord], now: Date = Date()) -> UsageSnapshot? {
        var percent: Double?
        var plan: String?
        var resetRelative: String?
        var resetDate: String?
        var onDemand: String?

        for record in records {
            let text = record.combinedText.trimmingCharacters(in: .whitespacesAndNewlines)
            let lower = text.lowercased()

            if lower.contains("weekly usage") {
                if let value = record.valueNumber, value >= 0, value <= 100 {
                    percent = value
                } else if let parsed = firstPercentage(in: text) {
                    percent = parsed
                }
            }
            if let value = value(after: "Current plan:", in: text) { plan = value }
            if let value = value(after: "Usage resets on", in: text) {
                resetDate = value.components(separatedBy: ".").first?.trimmingCharacters(in: .whitespaces)
            }
            if let value = value(after: "Resets in", in: text) { resetRelative = "Resets in " + value }
            if lower.contains("on-demand monthly limit") {
                if let explicit = record.valueText, !explicit.isEmpty, explicit.lowercased() != "on-demand monthly limit" {
                    onDemand = explicit
                } else if let value = value(after: "On-demand monthly limit", in: text) {
                    onDemand = value
                }
            }
        }

        guard let percent else { return nil }
        return UsageSnapshot(
            percentUsed: percent,
            plan: plan,
            resetDescription: resetRelative,
            resetDateDescription: resetDate,
            onDemandLimit: onDemand,
            capturedAt: now
        )
    }

    private static func firstPercentage(in text: String) -> Double? {
        guard let match = text.firstMatch(of: /([0-9]+(?:\.[0-9]+)?)\s*%/),
              let result = Double(match.output.1)
        else { return nil }
        return result
    }

    private static func value(after prefix: String, in text: String) -> String? {
        guard let range = text.range(of: prefix, options: .caseInsensitive) else { return nil }
        let suffix = text[range.upperBound...]
            .trimmingCharacters(in: CharacterSet(charactersIn: " :·\n\t"))
        return suffix.isEmpty ? nil : String(suffix.components(separatedBy: " · ").first ?? suffix)
    }
}

@MainActor
final class AccessibilityReader {
    private let bundleIdentifier = "com.anysphere.sand"

    var isTrusted: Bool { AXIsProcessTrusted() }

    func requestTrust() {
        AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
    }

    func records() -> [AXRecord] {
        guard isTrusted,
              let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).first
        else { return [] }
        return collect(from: AXUIElementCreateApplication(app.processIdentifier))
    }

    func bringGrokBotForward() {
        if let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).first {
            app.activate(options: [.activateAllWindows])
        } else if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) {
            NSWorkspace.shared.openApplication(at: url, configuration: .init())
        }
    }

    func openUsageAndRead() async -> UsageSnapshot? {
        guard isTrusted else {
            requestTrust()
            return nil
        }
        bringGrokBotForward()
        try? await Task.sleep(for: .milliseconds(350))

        if pressElement(matchingAny: ["open account menu"]) {
            try? await Task.sleep(for: .milliseconds(250))
        }
        if pressElement(matchingAny: ["weekly usage"]) {
            try? await Task.sleep(for: .milliseconds(700))
        } else if pressElement(matchingAny: ["settings"]) {
            try? await Task.sleep(for: .milliseconds(500))
            if pressElement(matchingAny: ["usage & billing", "usage and billing"]) {
                try? await Task.sleep(for: .milliseconds(700))
            }
        }
        return UsageParser.parse(records: records())
    }

    func readQuickUsage() async -> UsageSnapshot? {
        guard isTrusted else { return nil }
        if let visible = UsageParser.parse(records: records()) { return visible }
        guard pressElement(matchingAny: ["open account menu"]) else { return nil }
        try? await Task.sleep(for: .milliseconds(300))
        let snapshot = UsageParser.parse(records: records())
        _ = pressElement(matchingAny: ["open account menu"])
        return snapshot
    }

    private func pressElement(matchingAny needles: [String]) -> Bool {
        guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).first else { return false }
        let root = AXUIElementCreateApplication(app.processIdentifier)
        for element in collectElements(from: root) {
            let text = [stringAttribute(kAXTitleAttribute, element), stringAttribute(kAXDescriptionAttribute, element), stringAttribute(kAXHelpAttribute, element)]
                .compactMap { $0 }.joined(separator: " ").lowercased()
            if needles.contains(where: { text == $0 || text.contains($0) }),
               AXUIElementPerformAction(element, kAXPressAction as CFString) == .success {
                return true
            }
        }
        return false
    }

    private func collect(from root: AXUIElement) -> [AXRecord] {
        collectElements(from: root).map { element in
            let value = rawAttribute(kAXValueAttribute, element)
            return AXRecord(
                role: stringAttribute(kAXRoleAttribute, element) ?? "",
                title: stringAttribute(kAXTitleAttribute, element),
                description: stringAttribute(kAXDescriptionAttribute, element),
                help: stringAttribute(kAXHelpAttribute, element),
                valueText: value as? String,
                valueNumber: (value as? NSNumber)?.doubleValue,
                frame: frame(of: element)
            )
        }
    }

    private func collectElements(from root: AXUIElement) -> [AXUIElement] {
        var result: [AXUIElement] = []
        var queue: [(AXUIElement, Int)] = [(root, 0)]
        var index = 0
        while index < queue.count, result.count < 1_500 {
            let (element, depth) = queue[index]
            index += 1
            result.append(element)
            guard depth < 18,
                  let children = rawAttribute(kAXChildrenAttribute, element) as? [AXUIElement]
            else { continue }
            queue.append(contentsOf: children.map { ($0, depth + 1) })
        }
        return result
    }

    private func rawAttribute(_ attribute: String, _ element: AXUIElement) -> AnyObject? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else { return nil }
        return value
    }

    private func stringAttribute(_ attribute: String, _ element: AXUIElement) -> String? {
        rawAttribute(attribute, element) as? String
    }

    private func frame(of element: AXUIElement) -> CGRect? {
        guard let positionRaw = rawAttribute(kAXPositionAttribute, element),
              let sizeRaw = rawAttribute(kAXSizeAttribute, element),
              CFGetTypeID(positionRaw) == AXValueGetTypeID(),
              CFGetTypeID(sizeRaw) == AXValueGetTypeID()
        else { return nil }
        let positionValue = unsafeDowncast(positionRaw, to: AXValue.self)
        let sizeValue = unsafeDowncast(sizeRaw, to: AXValue.self)
        var position = CGPoint.zero
        var size = CGSize.zero
        guard AXValueGetValue(positionValue, .cgPoint, &position),
              AXValueGetValue(sizeValue, .cgSize, &size)
        else { return nil }
        return CGRect(origin: position, size: size)
    }
}
