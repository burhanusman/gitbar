import SwiftUI
import AppKit
import os.log

private let logger = Logger(subsystem: "com.gitbar.app", category: "App")

@main
struct GitBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            SettingsView()
        }
        .commands {
            CommandGroup(replacing: .appSettings) {
                Button("Open GitBar Window") {
                    appDelegate.openMainWindow()
                }
                .keyboardShortcut("o", modifiers: [.command, .shift])

                Divider()

                Button("Settings…") {
                    appDelegate.openSettings()
                }
                .keyboardShortcut(",", modifiers: .command)
            }
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    private let workspaceSession = WorkspaceSession()
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private lazy var statusMenu: NSMenu = makeStatusMenu()
    private var eventMonitor: EventMonitor?
    private var mainWindowController: GitBarMainWindowController?
    private var pendingMainWindowOpen = false
    private var pendingPopoverSettings = false
    private var isPopoverClosing = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        logger.info("🚀 GitBar app launched")
        setupMenuBar()

        // Close any auto-opened windows (Settings scene may auto-open on first launch)
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            for window in NSApp.windows {
                let isAutomaticallyOpenedSettingsWindow =
                    window.title.localizedCaseInsensitiveContains("settings")
                    || window.title == "GitBar"

                guard window.identifier != GitBarMainWindowController.windowIdentifier,
                      window != self.popover?.contentViewController?.view.window,
                      isAutomaticallyOpenedSettingsWindow else {
                    continue
                }
                window.close()
            }
        }
    }

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            button.image = makeStatusBarIcon()
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.action = #selector(handleStatusItemClick(_:))
            button.target = self
        }

        popover = NSPopover()
        popover?.contentSize = NSSize(width: 680, height: 520)
        popover?.behavior = .transient
        popover?.delegate = self

        eventMonitor = EventMonitor(mask: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.closePopoverIfClickedOutside()
        }
    }

    private func makePopoverContentViewController() -> NSViewController {
        let controller = NSHostingController(
            rootView: ContentView(
                session: workspaceSession,
                surface: .popover,
                onOpenWindow: { [weak self] in
                    self?.openMainWindow()
                }
            )
        )
        controller.sizingOptions = []
        return controller
    }

    private func makeStatusBarIcon() -> NSImage {
        let size = NSSize(width: 18, height: 18)

        let image = NSImage(size: size, flipped: false) { rect in
            func snap(_ value: CGFloat) -> CGFloat {
                (value * 2).rounded() / 2
            }

            let midX = snap(rect.midX)
            let bottomY = snap(rect.minY + 4)
            let middleY = snap(rect.minY + 9)
            let topY = snap(rect.minY + 14)
            let offsetX = snap(4)

            let bottom = CGPoint(x: midX, y: bottomY)
            let middle = CGPoint(x: midX, y: middleY)
            let topLeft = CGPoint(x: midX - offsetX, y: topY)
            let topRight = CGPoint(x: midX + offsetX, y: topY)

            let strokeWidth: CGFloat = 1.4
            let dotRadius: CGFloat = 1.6

            NSColor.black.setStroke()
            NSColor.black.setFill()

            let lines = NSBezierPath()
            lines.lineWidth = strokeWidth
            lines.lineCapStyle = .round

            lines.move(to: bottom)
            lines.line(to: middle)
            lines.line(to: topLeft)

            lines.move(to: middle)
            lines.line(to: topRight)
            lines.stroke()

            for point in [bottom, middle, topLeft, topRight] {
                let dotRect = CGRect(
                    x: point.x - dotRadius,
                    y: point.y - dotRadius,
                    width: dotRadius * 2,
                    height: dotRadius * 2
                )
                NSBezierPath(ovalIn: dotRect).fill()
            }

            return true
        }

        image.isTemplate = true
        return image
    }

    @objc private func handleStatusItemClick(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else {
            handlePrimaryStatusItemClick(sender)
            return
        }

        let isRightClick = event.type == .rightMouseUp ||
            (event.type == .leftMouseUp && event.modifierFlags.contains(.control))

        if isRightClick {
            showStatusMenu()
        } else {
            handlePrimaryStatusItemClick(sender)
        }
    }

    private func handlePrimaryStatusItemClick(_ sender: Any?) {
        if let mainWindowController, mainWindowController.isOpen {
            mainWindowController.showAndFocus(preferredScreen: statusItemScreen)
            return
        }

        togglePopover(sender)
    }

    private func showStatusMenu() {
        closePopover(nil)
        statusItem?.menu = statusMenu
        statusItem?.button?.performClick(nil)
        statusItem?.menu = nil
    }

    @objc private func togglePopover(_ sender: Any?) {
        guard let button = statusItem?.button, let popover = popover else { return }

        if popover.isShown {
            logger.debug("📦 Closing popover")
            closePopover(sender)
        } else {
            showPopover(relativeTo: button)
        }
    }

    private func showPopover(relativeTo button: NSStatusBarButton? = nil) {
        guard let button = button ?? statusItem?.button,
              let popover,
              !popover.isShown else {
            return
        }

        if popover.contentViewController == nil {
            popover.contentViewController = makePopoverContentViewController()
        }

        logger.debug("📦 Opening popover")
        isPopoverClosing = false
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        workspaceSession.activate(.popover)
        NSApp.activate(ignoringOtherApps: true)
        eventMonitor?.start()
    }

    private func closePopover(_ sender: Any?) {
        guard let popover, popover.isShown else {
            eventMonitor?.stop()
            return
        }

        isPopoverClosing = true
        popover.performClose(sender)
        eventMonitor?.stop()
    }

    private func closePopoverIfClickedOutside() {
        guard let popover, popover.isShown else { return }
        guard !isMouseInsidePopover() else { return }
        closePopover(nil)
    }

    private func isMouseInsidePopover() -> Bool {
        guard let window = popover?.contentViewController?.view.window else { return false }
        return window.frame.contains(NSEvent.mouseLocation)
    }

    func popoverDidClose(_ notification: Notification) {
        eventMonitor?.stop()
        isPopoverClosing = false

        if pendingMainWindowOpen {
            pendingMainWindowOpen = false
            presentMainWindow()
        }

        popover?.contentViewController = nil
        workspaceSession.deactivate(.popover)

        if pendingPopoverSettings {
            pendingPopoverSettings = false
            showPopover()
            workspaceSession.requestSettings(on: .popover)
        }
    }

    private func makeStatusMenu() -> NSMenu {
        let menu = NSMenu()

        let openWindow = NSMenuItem(
            title: "Open GitBar Window",
            action: #selector(openMainWindow),
            keyEquivalent: "o"
        )
        openWindow.keyEquivalentModifierMask = [.command, .shift]
        openWindow.target = self
        menu.addItem(openWindow)

        menu.addItem(.separator())

        let settings = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)

        menu.addItem(.separator())

        let quit = NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        return menu
    }

    @objc func openMainWindow() {
        logger.debug("🪟 Open window requested")

        if popover?.contentViewController?.view.window?.attachedSheet != nil {
            NSSound.beep()
            return
        }

        if popover?.isShown == true {
            pendingMainWindowOpen = true
            closePopover(nil)
            return
        }

        presentMainWindow()
    }

    private func presentMainWindow() {
        logger.debug("🪟 Presenting workspace window")

        let controller: GitBarMainWindowController
        if let mainWindowController {
            controller = mainWindowController
        } else {
            let newController = GitBarMainWindowController(
                session: workspaceSession,
                preferredScreen: statusItemScreen
            )
            mainWindowController = newController
            controller = newController
        }

        controller.showAndFocus(preferredScreen: statusItemScreen)
    }

    @objc func openSettings() {
        if let mainWindowController, mainWindowController.isOpen {
            mainWindowController.showAndFocus(preferredScreen: statusItemScreen)
            workspaceSession.requestSettings(on: .window)
            return
        }

        if isPopoverClosing {
            pendingPopoverSettings = true
            return
        }

        showPopover()
        workspaceSession.requestSettings(on: .popover)
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }

    func applicationShouldHandleReopen(
        _ sender: NSApplication,
        hasVisibleWindows flag: Bool
    ) -> Bool {
        openMainWindow()
        return false
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    private var statusItemScreen: NSScreen? {
        statusItem?.button?.window?.screen ?? NSScreen.main
    }
}

@MainActor
final class GitBarMainWindowController: NSWindowController, NSWindowDelegate {
    static let windowIdentifier = NSUserInterfaceItemIdentifier("GitBarMainWindow")

    private static let frameAutosaveName = "GitBarMainWindowFrame"
    private static let defaultSize = NSSize(width: 1180, height: 760)
    private static let minimumSize = NSSize(width: 860, height: 560)

    private let session: WorkspaceSession

    private(set) var isOpen = false

    init(session: WorkspaceSession, preferredScreen: NSScreen?) {
        self.session = session

        let initialFrame = Self.defaultFrame(on: preferredScreen)
        let window = NSWindow(
            contentRect: initialFrame,
            styleMask: [
                .titled,
                .closable,
                .miniaturizable,
                .resizable,
                .fullSizeContentView
            ],
            backing: .buffered,
            defer: false
        )

        window.identifier = Self.windowIdentifier
        window.title = "GitBar"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.isReleasedWhenClosed = false
        window.isRestorable = false
        window.tabbingMode = .disallowed
        window.minSize = Self.minimumSize
        window.collectionBehavior.insert(.fullScreenPrimary)

        super.init(window: window)

        shouldCascadeWindows = false
        window.delegate = self

        let restoredFrame = window.setFrameUsingName(Self.frameAutosaveName)
        if restoredFrame, Self.isMeaningfullyVisible(window.frame) {
            window.setFrame(
                Self.repairedFrame(window.frame, preferredScreen: preferredScreen),
                display: false
            )
        } else {
            window.setFrame(initialFrame, display: false)
        }
        window.setFrameAutosaveName(Self.frameAutosaveName)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func showAndFocus(preferredScreen: NSScreen?) {
        guard let window else { return }

        logger.debug("🪟 Showing workspace window")
        mountContentIfNeeded(in: window)

        if Self.isMeaningfullyVisible(window.frame) {
            window.setFrame(
                Self.repairedFrame(window.frame, preferredScreen: preferredScreen),
                display: false
            )
        } else {
            window.setFrame(Self.defaultFrame(on: preferredScreen), display: false)
        }

        isOpen = true
        session.activate(.window)
        showWindow(nil)

        if window.isMiniaturized {
            window.deminiaturize(nil)
        }

        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        logger.debug("🪟 Closing workspace window")
        isOpen = false
        window?.contentViewController = nil
        session.deactivate(.window)
    }

    private func mountContentIfNeeded(in window: NSWindow) {
        guard window.contentViewController == nil else { return }
        let controller = NSHostingController(
            rootView: ContentView(session: session, surface: .window)
        )
        controller.sizingOptions = []
        window.contentViewController = controller
        window.minSize = Self.minimumSize
    }

    private static func defaultFrame(on preferredScreen: NSScreen?) -> NSRect {
        guard let screen = preferredScreen ?? NSScreen.main ?? NSScreen.screens.first else {
            return NSRect(origin: .zero, size: defaultSize)
        }

        let visibleFrame = screen.visibleFrame
        let width = min(
            visibleFrame.width,
            min(defaultSize.width, max(minimumSize.width, visibleFrame.width - 80))
        )
        let height = min(
            visibleFrame.height,
            min(defaultSize.height, max(minimumSize.height, visibleFrame.height - 80))
        )

        return NSRect(
            x: visibleFrame.midX - width / 2,
            y: visibleFrame.midY - height / 2,
            width: width,
            height: height
        )
    }

    private static func isMeaningfullyVisible(_ frame: NSRect) -> Bool {
        NSScreen.screens.contains { screen in
            let intersection = screen.visibleFrame.intersection(frame)
            return intersection.width >= 120 && intersection.height >= 80
        }
    }

    private static func repairedFrame(
        _ frame: NSRect,
        preferredScreen: NSScreen?
    ) -> NSRect {
        func intersectionArea(on screen: NSScreen) -> CGFloat {
            let intersection = screen.visibleFrame.intersection(frame)
            guard !intersection.isNull else { return 0 }
            return intersection.width * intersection.height
        }

        guard let screen = NSScreen.screens.max(by: {
            intersectionArea(on: $0) < intersectionArea(on: $1)
        }) ?? preferredScreen ?? NSScreen.main else {
            return NSRect(
                origin: frame.origin,
                size: NSSize(
                    width: max(frame.width, minimumSize.width),
                    height: max(frame.height, minimumSize.height)
                )
            )
        }

        let visibleFrame = screen.visibleFrame
        var repaired = frame
        let minimumWidth = min(minimumSize.width, visibleFrame.width)
        let minimumHeight = min(minimumSize.height, visibleFrame.height)
        repaired.size.width = min(visibleFrame.width, max(frame.width, minimumWidth))
        repaired.size.height = min(visibleFrame.height, max(frame.height, minimumHeight))

        let maximumX = max(visibleFrame.minX, visibleFrame.maxX - repaired.width)
        let maximumY = max(visibleFrame.minY, visibleFrame.maxY - repaired.height)
        repaired.origin.x = min(max(repaired.minX, visibleFrame.minX), maximumX)
        repaired.origin.y = min(max(repaired.minY, visibleFrame.minY), maximumY)

        return repaired
    }
}
