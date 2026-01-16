import SwiftUI
import AppKit

extension Notification.Name {
    static let openSettings = Notification.Name("GitBar.openSettings")
}

@main
struct GitBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private lazy var statusMenu: NSMenu = makeStatusMenu()
    private var eventMonitor: EventMonitor?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuBar()
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
        popover?.contentSize = NSSize(width: 560, height: 520)
        popover?.behavior = .transient
        popover?.contentViewController = NSHostingController(rootView: ContentView())
        popover?.delegate = self

        eventMonitor = EventMonitor(mask: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.closePopoverIfClickedOutside()
        }
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
            togglePopover(sender)
            return
        }

        let isRightClick = event.type == .rightMouseUp ||
            (event.type == .leftMouseUp && event.modifierFlags.contains(.control))

        if isRightClick {
            showStatusMenu()
        } else {
            togglePopover(sender)
        }
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
            closePopover(sender)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            NSApp.activate(ignoringOtherApps: true)
            eventMonitor?.start()
        }
    }

    private func closePopover(_ sender: Any?) {
        popover?.performClose(sender)
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
    }

    private func makeStatusMenu() -> NSMenu {
        let menu = NSMenu()

        let settings = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)

        menu.addItem(.separator())

        let quit = NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        return menu
    }

    @objc private func openSettings() {
        if let button = statusItem?.button, let popover, !popover.isShown {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
        NotificationCenter.default.post(name: .openSettings, object: nil)
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
}
