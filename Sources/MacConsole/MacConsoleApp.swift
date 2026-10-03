import AppKit
import Combine
import SwiftUI

@main
enum MacConsoleApp {
    @MainActor
    static func main() {
        let application = NSApplication.shared
        let delegate = ConsoleAppDelegate()
        application.delegate = delegate
        application.setActivationPolicy(.accessory)
        withExtendedLifetime(delegate) { application.run() }
    }
}

private final class ConsolePanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

@MainActor
private final class ConsoleAppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let model = PreviewModel()
    private var panel: ConsolePanel!
    private var statusItem: NSStatusItem!
    private var subscriptions = Set<AnyCancellable>()
    private var lockMenuItem: NSMenuItem!
    private var compactMenuItem: NSMenuItem!

    func applicationDidFinishLaunching(_ notification: Notification) {
        configurePanel()
        configureMenuBar()
        model.startSystemUpdates()
        model.startQuotaUpdates()
        model.$isPinned.sink { [weak self] isPinned in
            self?.panel.level = isPinned ? .floating : .normal
        }.store(in: &subscriptions)
        model.$isLocked.sink { [weak self] isLocked in
            self?.panel.isMovable = !isLocked
            self?.panel.isMovableByWindowBackground = self?.model.isCompact == true && !isLocked
        }.store(in: &subscriptions)
        model.$isCompact.combineLatest(model.$areShortcutsExpanded).combineLatest(model.$selectedMetric)
            // @Published emits before assignment. Resize on the next run-loop pass
            // so AppKit does not force SwiftUI to render the previous layout.
            .receive(on: DispatchQueue.main)
            .sink { [weak self] sizes, detail in
                let (compact, expanded) = sizes
                self?.panel.alphaValue = compact ? PreviewModel.compactOpacity : 1
                self?.panel.isMovableByWindowBackground = compact && self?.model.isLocked == false
                self?.resizePanel(to: PreviewModel.panelSize(compact: compact,
                                                               shortcutsExpanded: expanded,
                                                               metricDetail: detail))
            }.store(in: &subscriptions)
        showConsole()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showConsole()
        return false
    }

    func applicationWillTerminate(_ notification: Notification) {
        model.stopSystemUpdates()
        model.stopQuotaUpdates()
    }

    private func configurePanel() {
        let size = PreviewModel.panelSize(compact: model.isCompact,
                                          shortcutsExpanded: model.areShortcutsExpanded,
                                          metricDetail: model.selectedMetric)
        panel = ConsolePanel(contentRect: NSRect(origin: .zero, size: size),
                             styleMask: [.borderless],
                             backing: .buffered, defer: false)
        panel.title = "系统控制台"
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.appearance = NSAppearance(named: .aqua)
        let view = ConsoleView(model: model) { [weak self] in self?.panel.orderOut(nil) }
        let hostingView = NSHostingView(rootView: view)
        hostingView.sizingOptions = []
        panel.contentView = hostingView
        panel.setContentSize(size)
        if let screen = NSScreen.main {
            let area = screen.visibleFrame
            panel.setFrameOrigin(NSPoint(x: area.maxX - panel.frame.width - 24,
                                         y: area.maxY - panel.frame.height - 24))
        }
    }

    private func resizePanel(to size: CGSize) {
        let oldFrame = panel.frame
        var origin = NSPoint(x: oldFrame.maxX - size.width, y: oldFrame.maxY - size.height)
        if let visible = panel.screen?.visibleFrame {
            origin.x = max(visible.minX, min(origin.x, visible.maxX - size.width))
            origin.y = max(visible.minY, min(origin.y, visible.maxY - size.height))
        }
        panel.setFrame(NSRect(origin: origin, size: size), display: true)
    }

    private func configureMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "slider.horizontal.3", accessibilityDescription: "系统控制台")
        statusItem.button?.image?.isTemplate = true
        statusItem.button?.toolTip = "系统控制台 · 实时指标"
        let menu = NSMenu()
        menu.delegate = self
        let showItem = NSMenuItem(title: "显示系统控制台", action: #selector(showConsole), keyEquivalent: "")
        showItem.target = self
        menu.addItem(showItem)
        compactMenuItem = NSMenuItem(title: "缩小为缩略状态", action: #selector(toggleCompact), keyEquivalent: "")
        compactMenuItem.target = self
        menu.addItem(compactMenuItem)
        lockMenuItem = NSMenuItem(title: "锁定位置", action: #selector(toggleLock), keyEquivalent: "")
        lockMenuItem.target = self
        menu.addItem(lockMenuItem)
        menu.addItem(.separator())
        let quitItem = NSMenuItem(title: "退出系统控制台", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        statusItem.menu = menu
    }

    func menuWillOpen(_ menu: NSMenu) {
        compactMenuItem.title = model.isCompact ? "恢复完整控制台" : "缩小为缩略状态"
        lockMenuItem.title = model.isLocked ? "解锁位置" : "锁定位置"
        lockMenuItem.state = model.isLocked ? .on : .off
    }

    @objc private func toggleCompact() {
        if model.isCompact { model.isCompact = false } else { model.enterCompact() }
        showConsole()
    }

    @objc private func toggleLock() { model.isLocked.toggle() }

    @objc private func showConsole() {
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
