import AppKit

class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private let monitor = NetworkMonitor.shared

    private enum Tag: Int { case ip = 1, isp, latency, loss }

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        buildMenu()
        refresh()
        monitor.onChange = { [weak self] in self?.refresh() }
        monitor.start()
    }

    // MARK: – Refresh

    private func refresh() {
        statusItem.button?.image = statusIcon(quality: monitor.quality)
        guard let menu = statusItem.menu else { return }
        menu.item(withTag: Tag.ip.rawValue)?.title      = "IP:       \(monitor.publicIP)"
        menu.item(withTag: Tag.isp.rawValue)?.title     = "ISP:     \(monitor.isp)"
        menu.item(withTag: Tag.latency.rawValue)?.title = "Latency: \(monitor.avgLatencyString)"
        menu.item(withTag: Tag.loss.rawValue)?.title    = "Loss:    \(monitor.packetLossString)"
    }

    // MARK: – Menu

    private func buildMenu() {
        let menu = NSMenu()

        menu.addItem(tagged("IP:       —",        tag: .ip))
        menu.addItem(tagged("ISP:     —",         tag: .isp))
        menu.addItem(tagged("Latency: —",         tag: .latency))
        menu.addItem(tagged("Loss:    —",         tag: .loss))
        menu.addItem(.separator())

        let details = NSMenuItem(title: "View Full Details…", action: #selector(openDetails), keyEquivalent: "")
        details.target = self
        menu.addItem(details)

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit NetStatBar",
                                action: #selector(NSApplication.terminate(_:)),
                                keyEquivalent: "q"))
        menu.delegate = self
        statusItem.menu = menu
    }

    func menuWillOpen(_ menu: NSMenu) {
        menu.item(withTag: Tag.ip.rawValue)?.title  = "IP:       fetching…"
        menu.item(withTag: Tag.isp.rawValue)?.title = "ISP:     fetching…"
        monitor.fetchNetworkInfo()
    }

    private func tagged(_ title: String, tag: Tag) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.tag = tag.rawValue
        return item
    }

    @objc private func openDetails() {
        if let url = URL(string: workerURL + "?json") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: – Icon

    private func statusIcon(quality: Double) -> NSImage {
        let size: CGFloat = 14
        let image = NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
            self.qualityColor(quality).setFill()
            NSBezierPath(ovalIn: rect.insetBy(dx: 1, dy: 1)).fill()
            return true
        }
        image.isTemplate = false
        return image
    }

    /// Smooth green → yellow → red gradient
    private func qualityColor(_ q: Double) -> NSColor {
        if q >= 0.5 {
            let t = (q - 0.5) * 2          // 0 = yellow, 1 = green
            return NSColor(red: 1.0 - t,
                           green: 0.75 + 0.05 * t,
                           blue:  0.2  * t,
                           alpha: 1)
        } else {
            let t = q * 2                  // 0 = red, 1 = yellow
            return NSColor(red: 0.9 + 0.1 * t,
                           green: 0.1 + 0.65 * t,
                           blue:  0,
                           alpha: 1)
        }
    }
}
