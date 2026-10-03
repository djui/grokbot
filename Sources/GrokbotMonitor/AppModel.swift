import AppKit
import Combine
import Foundation
import ServiceManagement
import UserNotifications

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var bots: [BotPresentation] = []
    @Published private(set) var events: [ActivityEvent] = []
    @Published private(set) var usage: UsageSnapshot?
    @Published private(set) var isGrokBotRunning = false
    @Published private(set) var isAccessibilityTrusted = false
    @Published private(set) var lastChecked = Date()
    @Published var notificationsEnabled: Bool {
        didSet { defaults.set(notificationsEnabled, forKey: Keys.notifications) }
    }

    private let rosterStore: RosterStore
    private let statusStore: DesktopStatusStore
    private let accessibility = AccessibilityReader()
    private let defaults: UserDefaults
    private var timer: Timer?
    private var previousStates: [String: BotState] = [:]

    private enum Keys {
        static let events = "activityEvents.v1"
        static let usage = "usageSnapshot.v1"
        static let notifications = "notificationsEnabled"
    }

    init(
        rosterStore: RosterStore = .init(),
        statusStore: DesktopStatusStore = .init(),
        defaults: UserDefaults = .standard
    ) {
        self.rosterStore = rosterStore
        self.statusStore = statusStore
        self.defaults = defaults
        notificationsEnabled = defaults.bool(forKey: Keys.notifications)
        events = Self.decode([ActivityEvent].self, from: defaults.data(forKey: Keys.events)) ?? []
        usage = Self.decode(UsageSnapshot.self, from: defaults.data(forKey: Keys.usage))
    }

    func start() {
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    func refresh() {
        isGrokBotRunning = statusStore.load() != nil
        isAccessibilityTrusted = accessibility.isTrusted
        let roster = (try? rosterStore.load()) ?? []
        let records = isAccessibilityTrusted && isGrokBotRunning ? accessibility.records() : []

        if let parsedUsage = UsageParser.parse(records: records) {
            usage = merge(new: parsedUsage, old: usage)
            persistUsage()
        }

        let presentations = roster.map { bot -> BotPresentation in
            if bot.awaitingUserResponse != nil {
                return BotPresentation(bot: bot, state: .needsYou, detail: "Waiting for you")
            }
            if let classified = ActivityTextClassifier.classify(botName: bot.name, records: records) {
                return BotPresentation(bot: bot, state: classified.0, detail: classified.1)
            }
            if (bot.unreadCount ?? 0) > 0 || bot.hasUnread == true {
                return BotPresentation(bot: bot, state: .unread, detail: "New update")
            }
            return BotPresentation(bot: bot, state: .idle, detail: nil)
        }
        recordChanges(from: bots, to: presentations)
        bots = presentations
        lastChecked = Date()
    }

    func requestAccessibility() {
        accessibility.requestTrust()
    }

    func refreshUsage() {
        Task { @MainActor in
            if let fresh = await accessibility.openUsageAndRead() {
                usage = merge(new: fresh, old: usage)
                persistUsage()
            }
            refresh()
        }
    }

    func openGrokBot() { accessibility.bringGrokBotForward() }

    var activeBots: [BotPresentation] { bots.filter { $0.state == .active } }
    var attentionBots: [BotPresentation] { bots.filter { $0.state == .needsYou || $0.state == .failed } }
    var statusBot: BotPresentation? { activeBots.first ?? attentionBots.first }

    var launchAtLoginEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
            objectWillChange.send()
        } catch {
            NSSound.beep()
        }
    }

    func setNotifications(_ enabled: Bool) {
        notificationsEnabled = enabled
        guard enabled else { return }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    private func recordChanges(from old: [BotPresentation], to new: [BotPresentation]) {
        if previousStates.isEmpty {
            previousStates = Dictionary(uniqueKeysWithValues: old.map { ($0.id, $0.state) })
        }
        for item in new {
            let previous = previousStates[item.id]
            previousStates[item.id] = item.state
            guard let previous, previous != item.state,
                  [.active, .needsYou, .failed, .unread].contains(item.state)
            else { continue }

            let event = ActivityEvent(
                id: UUID(), botID: item.id, botName: item.bot.name,
                avatarColor: item.bot.avatarColor, avatarShape: item.bot.avatarShape,
                state: item.state, date: Date(), detail: item.detail
            )
            events.insert(event, at: 0)
            events = Array(events.prefix(40))
            defaults.set(try? JSONEncoder().encode(events), forKey: Keys.events)
            notify(event)
        }
    }

    private func notify(_ event: ActivityEvent) {
        guard notificationsEnabled, [.needsYou, .failed].contains(event.state) else { return }
        let content = UNMutableNotificationContent()
        content.title = event.botName
        content.body = event.state == .needsYou ? "This Grokbot needs your attention." : "This Grokbot ran into a problem."
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: event.id.uuidString, content: content, trigger: nil))
    }

    private func merge(new: UsageSnapshot, old: UsageSnapshot?) -> UsageSnapshot {
        UsageSnapshot(
            percentUsed: new.percentUsed,
            plan: new.plan ?? old?.plan,
            resetDescription: new.resetDescription ?? old?.resetDescription,
            resetDateDescription: new.resetDateDescription ?? old?.resetDateDescription,
            onDemandLimit: new.onDemandLimit ?? old?.onDemandLimit,
            capturedAt: new.capturedAt
        )
    }

    private func persistUsage() {
        defaults.set(try? JSONEncoder().encode(usage), forKey: Keys.usage)
    }

    private static func decode<T: Decodable>(_ type: T.Type, from data: Data?) -> T? {
        guard let data else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}
