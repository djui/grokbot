import AppKit
import ApplicationServices
import Combine
import SwiftUI

@main
struct GrokbotMonitorMain {
    @MainActor
    static func main() {
        if CommandLine.arguments.contains("--check-accessibility") {
            print(AXIsProcessTrusted() ? "Accessibility: trusted" : "Accessibility: permission required")
            print("Bundle: \(Bundle.main.bundleURL.path)")
            return
        }
        let application = NSApplication.shared
        let previewMode = CommandLine.arguments.contains("--preview")
        let delegate = AppDelegate(previewMode: previewMode)
        application.delegate = delegate
        application.setActivationPolicy(previewMode ? .regular : .accessory)
        application.run()
        withExtendedLifetime(delegate) {}
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    private let model = AppModel()
    private let popover = NSPopover()
    private let previewMode: Bool
    private var statusItem: NSStatusItem?
    private var previewWindow: NSWindow?
    private var cancellables = Set<AnyCancellable>()

    init(previewMode: Bool = false) {
        self.previewMode = previewMode
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.target = self
        item.button?.action = #selector(togglePopover(_:))
        item.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        statusItem = item

        popover.behavior = .transient
        popover.animates = true
        popover.delegate = self
        popover.contentSize = NSSize(width: 410, height: 570)
        popover.contentViewController = NSHostingController(rootView: PopoverView(model: model))

        model.$bots
            .combineLatest(model.$isGrokBotRunning)
            .receive(on: RunLoop.main)
            .sink { [weak self] _, _ in self?.updateStatusItem() }
            .store(in: &cancellables)

        model.start()
        updateStatusItem()

        if previewMode {
            let controller = NSHostingController(rootView: PopoverView(model: model))
            let window = NSWindow(contentViewController: controller)
            window.title = "Grokbot Monitor Preview"
            window.setContentSize(NSSize(width: 410, height: 570))
            window.styleMask = [.titled, .closable, .miniaturizable]
            window.center()
            window.makeKeyAndOrderFront(nil)
            NSApplication.shared.activate(ignoringOtherApps: true)
            previewWindow = window
        }
    }

    @objc private func togglePopover(_ sender: NSStatusBarButton) {
        if popover.isShown {
            popover.performClose(sender)
        } else {
            popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    private func updateStatusItem() {
        guard let button = statusItem?.button else { return }
        // Only an actively working bot replaces the default monochrome icon.
        let selected = model.activeBots.first
        button.image = StatusIconRenderer.image(
            colorName: selected?.bot.avatarColor ?? "black",
            shape: selected?.bot.avatarShape ?? "blob",
            isTemplate: selected == nil
        )
        button.imagePosition = .imageLeading
        button.title = model.activeBots.count > 1 ? "\(model.activeBots.count)" : ""
        button.toolTip = model.activeBots.first.map { "\($0.bot.name) is working" }
            ?? (model.isGrokBotRunning ? "Grokbots are quiet" : "Grok Bot is offline")
        button.setAccessibilityLabel(button.toolTip ?? "Grokbot Monitor")
    }
}
