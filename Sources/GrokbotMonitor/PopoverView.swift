import AppKit
import SwiftUI

struct PopoverView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            header
            separator
            usageSummary
            separator
            ScrollView {
                VStack(spacing: 14) {
                    if !model.isAccessibilityTrusted { permissionCard }
                    botsCard
                    activityCard
                }
                .padding(16)
            }
            separator
            footer
        }
        .frame(width: 410, height: 570)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.primary.opacity(0.12), lineWidth: 0.75)
        }
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

    private var usageSummary: some View {
        HStack(spacing: 10) {
            Image(systemName: "gauge.with.dots.needle.50percent")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.secondary)
            if let usage = model.usage {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 5) {
                        Text(usage.percentLabel).font(.subheadline.weight(.semibold).monospacedDigit())
                        Text("weekly usage").font(.caption).foregroundStyle(.secondary)
                        if let plan = usage.plan {
                            Text(plan).font(.caption2.weight(.semibold))
                                .padding(.horizontal, 5).padding(.vertical, 1)
                                .background(.quaternary, in: Capsule())
                        }
                    }
                    Text(usageLine(usage)).font(.caption2).foregroundStyle(.tertiary).lineLimit(1)
                }
                Spacer()
                ProgressView(value: usage.fractionUsed)
                    .progressViewStyle(.circular)
                    .controlSize(.small)
                    .tint(usage.fractionUsed > 0.85 ? .orange : .accentColor)
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Usage & limits").font(.subheadline.weight(.semibold))
                    Text("Refresh once to read the current allowance").font(.caption2).foregroundStyle(.secondary)
                }
                Spacer()
            }
            Button { model.refreshUsage() } label: {
                if model.isUsageLoading { ProgressView().controlSize(.small) }
                else { Image(systemName: "arrow.clockwise") }
            }
            .buttonStyle(.borderless)
            .disabled(model.isUsageLoading)
            .help("Refresh from Grok Bot Usage & Billing")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
        .frame(minHeight: 52)
    }

    private func usageLine(_ usage: UsageSnapshot) -> String {
        let reset = usage.resetDateDescription.map { "Resets \($0)" } ?? usage.resetDescription ?? "Reset unavailable"
        let demand = usage.onDemandLimit.map { "On-demand: \($0)" }
        return [reset, demand].compactMap { $0 }.joined(separator: "  ·  ")
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
            .background(Color.primary.opacity(0.045), in: shape)
            .overlay(shape.stroke(Color.primary.opacity(0.08), lineWidth: 0.5))
    }

    private var separator: some View {
        Rectangle().fill(Color.primary.opacity(0.09)).frame(height: 0.5)
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
