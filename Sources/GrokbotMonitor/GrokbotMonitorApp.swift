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
        let panelPreviewMode = CommandLine.arguments.contains("--panel-preview")
        let delegate = AppDelegate(previewMode: previewMode, panelPreviewMode: panelPreviewMode)
        application.delegate = delegate
        application.setActivationPolicy(previewMode || panelPreviewMode ? .regular : .accessory)
        application.run()
        withExtendedLifetime(delegate) {}
    }
}

final class MenuPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let model = AppModel()
    private let panel: MenuPanel
    private let previewMode: Bool
    private let panelPreviewMode: Bool
    private var statusItem: NSStatusItem?
    private var previewWindow: NSWindow?
    private var cancellables = Set<AnyCancellable>()
    private var globalClickMonitor: Any?
    private var localEventMonitor: Any?

    init(previewMode: Bool = false, panelPreviewMode: Bool = false) {
        self.previewMode = previewMode
        self.panelPreviewMode = panelPreviewMode
        panel = MenuPanel(
            contentRect: NSRect(x: 0, y: 0, width: 410, height: 570),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.target = self
        item.button?.action = #selector(togglePopover(_:))
        item.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        statusItem = item

        panel.contentViewController = NSHostingController(rootView: PopoverView(model: model))
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .popUpMenu
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.transient, .moveToActiveSpace, .fullScreenAuxiliary]

        globalClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            Task { @MainActor in self?.panel.orderOut(nil) }
        }
        localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .keyDown]) { [weak self] event in
            guard let self else { return event }
            if event.type == .keyDown, event.keyCode == 53 {
                self.panel.orderOut(nil)
            } else if self.panel.isVisible,
                      event.window !== self.panel,
                      event.window !== self.statusItem?.button?.window {
                self.panel.orderOut(nil)
            }
            return event
        }

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
        } else if panelPreviewMode {
            model.panelOpened()
            panel.center()
            panel.orderFrontRegardless()
            panel.makeKey()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let globalClickMonitor { NSEvent.removeMonitor(globalClickMonitor) }
        if let localEventMonitor { NSEvent.removeMonitor(localEventMonitor) }
    }

    @objc private func togglePopover(_ sender: NSStatusBarButton) {
        if panel.isVisible {
            panel.orderOut(sender)
        } else {
            model.panelOpened()
            positionPanel(below: sender)
            panel.orderFrontRegardless()
            panel.makeKey()
        }
    }

    private func positionPanel(below button: NSStatusBarButton) {
        guard let window = button.window else { return }
        let buttonRect = window.convertToScreen(button.convert(button.bounds, to: nil))
        let visibleFrame = window.screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? .zero
        let panelSize = panel.frame.size
        var x = buttonRect.midX - panelSize.width / 2
        x = min(max(x, visibleFrame.minX + 8), visibleFrame.maxX - panelSize.width - 8)
        let y = buttonRect.minY - panelSize.height - 7
        panel.setFrameOrigin(NSPoint(x: x, y: y))
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
