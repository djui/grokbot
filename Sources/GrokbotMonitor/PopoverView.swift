import AppKit
import SwiftUI

struct PopoverView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView {
                VStack(spacing: 14) {
                    if !model.isAccessibilityTrusted { permissionCard }
                    usageCard
                    botsCard
                    activityCard
                }
                .padding(16)
            }
            Divider()
            footer
        }
        .frame(width: 410, height: 570)
        .background(.ultraThinMaterial)
    }

    private var header: some View {
        HStack(spacing: 11) {
            if let item = model.statusBot {
                GrokbotAvatar(colorName: item.bot.avatarColor, shape: item.bot.avatarShape, size: 34)
            } else {
                GrokbotAvatar(colorName: "black", shape: "blob", size: 34)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(headline).font(.headline)
                Text(subheadline).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            settingsMenu
        }
        .padding(16)
    }

    private var headline: String {
        if let active = model.activeBots.first { return "\(active.bot.name) is working" }
        if let attention = model.attentionBots.first { return "\(attention.bot.name) needs you" }
        return model.isGrokBotRunning ? "Grokbots are quiet" : "Grok Bot is offline"
    }

    private var subheadline: String {
        if model.activeBots.count > 1 { return "\(model.activeBots.count) active Grokbots" }
        if let detail = model.statusBot?.detail, !detail.isEmpty { return detail }
        return model.bots.isEmpty ? "Waiting for local roster data" : "\(model.bots.count) Grokbots watched locally"
    }

    private var settingsMenu: some View {
        Menu {
            Button("About Grokbot Monitor") { showAbout() }
            Link("View on GitHub", destination: URL(string: "https://github.com/djui/grokbot")!)
            Divider()
            Toggle("Launch at login", isOn: Binding(
                get: { model.launchAtLoginEnabled },
                set: { model.setLaunchAtLogin($0) }
            ))
            Toggle("Attention notifications", isOn: Binding(
                get: { model.notificationsEnabled },
                set: { model.setNotifications($0) }
            ))
            Divider()
            Button("Open Grok Bot") { model.openGrokBot() }
            Button("Quit Grokbot Monitor") { NSApplication.shared.terminate(nil) }
        } label: {
            Image(systemName: "gearshape")
                .font(.system(size: 15, weight: .medium))
                .frame(width: 28, height: 28)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }

    private func showAbout() {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Development"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        let link = NSMutableAttributedString(string: "Grokbot Monitor is local-only and open source.\n\nGitHub: djui/grokbot")
        let repository = "djui/grokbot"
        let range = (link.string as NSString).range(of: repository)
        link.addAttributes([
            .link: URL(string: "https://github.com/djui/grokbot")!,
            .foregroundColor: NSColor.linkColor,
            .underlineStyle: NSUnderlineStyle.single.rawValue
        ], range: range)

        var options: [NSApplication.AboutPanelOptionKey: Any] = [
            .applicationName: "Grokbot Monitor",
            .applicationVersion: version,
            .applicationIcon: StatusIconRenderer.image(colorName: "black", shape: "blob", isTemplate: false, size: 96),
            .credits: link
        ]
        if let build { options[.version] = build }
        NSApplication.shared.orderFrontStandardAboutPanel(options: options)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    private var permissionCard: some View {
        card {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "accessibility")
                    .font(.title3).foregroundStyle(.blue)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Live activity needs Accessibility").font(.subheadline.weight(.semibold))
                    Text("Used only to read Grok Bot’s status labels and usage screen. Conversation text and credentials are never stored.")
                        .font(.caption).foregroundStyle(.secondary)
                    Button("Allow Access") { model.requestAccessibility() }
                        .buttonStyle(.borderedProminent).controlSize(.small).padding(.top, 3)
                }
            }
        }
    }

    private var usageCard: some View {
        card {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("Usage & limits", systemImage: "gauge.with.dots.needle.50percent")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Button {
                        model.refreshUsage()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(.borderless)
                    .help("Open Usage & Billing in Grok Bot and refresh")
                }
                if let usage = model.usage {
                    HStack(alignment: .firstTextBaseline) {
                        Text(usage.percentLabel).font(.system(size: 23, weight: .semibold, design: .rounded))
                        Text("of weekly usage").font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        if let plan = usage.plan { Text(plan).font(.caption.weight(.medium)).padding(.horizontal, 7).padding(.vertical, 3).background(.quaternary, in: Capsule()) }
                    }
                    ProgressView(value: usage.fractionUsed).tint(usage.fractionUsed > 0.85 ? .orange : .blue)
                    HStack {
                        Text(usage.resetDateDescription.map { "Resets \($0)" } ?? usage.resetDescription ?? "Reset date unavailable")
                        Spacer()
                        Text("On-demand: \(usage.onDemandLimit ?? "—")")
                    }
                    .font(.caption).foregroundStyle(.secondary)
                    Text("Updated \(usage.capturedAt, style: .relative) ago")
                        .font(.caption2).foregroundStyle(.tertiary)
                } else {
                    Text("Open Usage & Billing once to capture your current plan, weekly usage, reset, and on-demand limit.")
                        .font(.caption).foregroundStyle(.secondary)
                    Button("Refresh from Grok Bot") { model.refreshUsage() }
                        .buttonStyle(.bordered).controlSize(.small)
                }
            }
        }
    }

    private var botsCard: some View {
        card {
            VStack(alignment: .leading, spacing: 10) {
                Text("Grokbots").font(.subheadline.weight(.semibold))
                if model.bots.isEmpty {
                    Text("No local Grokbots found yet.").font(.caption).foregroundStyle(.secondary)
                } else {
                    ForEach(model.bots.prefix(6)) { item in
                        HStack(spacing: 9) {
                            GrokbotAvatar(colorName: item.bot.avatarColor, shape: item.bot.avatarShape, size: 25)
                            Text(item.bot.name).lineLimit(1)
                            Spacer()
                            Circle().fill(stateColor(item.state)).frame(width: 7, height: 7)
                            Text(item.state.label).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    private var activityCard: some View {
        card {
            VStack(alignment: .leading, spacing: 11) {
                Text("Recent activity").font(.subheadline.weight(.semibold))
                if model.events.isEmpty {
                    Text("State changes will appear here—without message contents.")
                        .font(.caption).foregroundStyle(.secondary)
                } else {
                    ForEach(model.events.prefix(8)) { event in
                        HStack(alignment: .top, spacing: 9) {
                            GrokbotAvatar(colorName: event.avatarColor, shape: event.avatarShape, size: 25)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(event.botName).font(.callout.weight(.medium)).lineLimit(1)
                                Text(event.detail ?? event.state.label).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                            }
                            Spacer()
                            Text(event.date, style: .relative).font(.caption2).foregroundStyle(.tertiary)
                        }
                    }
                }
            }
        }
    }

    private var footer: some View {
        HStack {
            Circle().fill(model.isGrokBotRunning ? Color.green : Color.secondary).frame(width: 7, height: 7)
            Text(model.isGrokBotRunning ? "Grok Bot connected" : "Grok Bot not running")
            Spacer()
            Button("Open Grok Bot") { model.openGrokBot() }.buttonStyle(.link)
        }
        .font(.caption).foregroundStyle(.secondary).padding(.horizontal, 16).padding(.vertical, 11)
    }

    private func card<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
        return content()
            .padding(13)
            .frame(maxWidth: .infinity, alignment: .leading)
            .grokbotGlass(in: shape)
    }

    private func stateColor(_ state: BotState) -> Color {
        switch state {
        case .active: .green
        case .needsYou: .orange
        case .failed: .red
        case .finished: .blue
        case .unread: .purple
        case .idle: .secondary
        }
    }
}

private extension View {
    @ViewBuilder
    func grokbotGlass(in shape: RoundedRectangle) -> some View {
        if #available(macOS 26.0, *) {
            self.glassEffect(.regular, in: shape)
        } else {
            self
                .background(.thinMaterial, in: shape)
                .overlay(shape.stroke(Color.white.opacity(0.16), lineWidth: 0.75))
        }
    }
}
