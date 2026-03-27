import AppKit

class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private let monitor = NetworkMonitor.shared

    private enum Tag: Int { case ip = 1, isp, latency, loss, pingHistory, wifiSSID, wifiBSSID, wifiRSSI, wifiChannel }

    private let pingThreshold: Double = 100 // ms — above this shows red

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

        let rssi    = monitor.wifiRSSI
        let channel = monitor.wifiChannel

        let rssiStr = rssi != 0 ? "\(rssi) dBm" : "—"
        let chStr   = channel > 0
            ? "\(channel)  \(monitor.wifiChannelBand)  \(monitor.wifiChannelWidth)"
            : "—"

        menu.item(withTag: Tag.wifiSSID.rawValue)?.title    = "SSID:    \(monitor.wifiSSID)"
        menu.item(withTag: Tag.wifiBSSID.rawValue)?.title   = "BSSID:   \(monitor.wifiBSSID)"
        menu.item(withTag: Tag.wifiRSSI.rawValue)?.title   = "RSSI:    \(rssiStr)"
        menu.item(withTag: Tag.wifiChannel.rawValue)?.title = "Channel: \(chStr)"
    }

    // MARK: – Menu

    private func buildMenu() {
        let menu = NSMenu()

        menu.addItem(tagged("IP:       —", tag: .ip))
        menu.addItem(tagged("ISP:     —",  tag: .isp))
        menu.addItem(tagged("Latency: —",  tag: .latency))
        menu.addItem(tagged("Loss:    —",  tag: .loss))

        menu.addItem(.separator())

        let wifiHeader = NSMenuItem(title: "Wi-Fi", action: nil, keyEquivalent: "")
        wifiHeader.isEnabled = false
        menu.addItem(wifiHeader)
        menu.addItem(tagged("SSID:    —",  tag: .wifiSSID))
        menu.addItem(tagged("BSSID:   —",  tag: .wifiBSSID))
        menu.addItem(tagged("RSSI:    —",  tag: .wifiRSSI))
        menu.addItem(tagged("Channel: —",  tag: .wifiChannel))

        menu.addItem(.separator())

        let details = NSMenuItem(title: "View Full Details…", action: #selector(openDetails), keyEquivalent: "")
        details.target = self
        menu.addItem(details)

        let historyItem = NSMenuItem(title: "Last 10 Pings", action: nil, keyEquivalent: "")
        historyItem.tag = Tag.pingHistory.rawValue
        historyItem.submenu = NSMenu()
        menu.addItem(historyItem)

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit NetStatBar",
                                action: #selector(NSApplication.terminate(_:)),
                                keyEquivalent: "q"))
        menu.delegate = self
        statusItem.menu = menu
    }

    func menuWillOpen(_ menu: NSMenu) {
        menu.item(withTag: Tag.ip.rawValue)?.title   = "IP:       fetching…"
        menu.item(withTag: Tag.isp.rawValue)?.title  = "ISP:     fetching…"
        menu.item(withTag: Tag.wifiSSID.rawValue)?.title = "SSID:    fetching…"
        monitor.fetchNetworkInfo()
        refreshPingHistory()
    }

    private func refreshPingHistory() {
        guard let historyItem = statusItem.menu?.item(withTag: Tag.pingHistory.rawValue) else { return }
        let sub = NSMenu()

        // Graph item
        let graphView = PingGraphView(frame: NSRect(x: 0, y: 0, width: 280, height: 70))
        graphView.pings = monitor.pings
        graphView.threshold = pingThreshold
        let graphItem = NSMenuItem()
        graphItem.view = graphView
        sub.addItem(graphItem)

        sub.addItem(.separator())

        // Text list — bold = inside 10s window, red = above threshold or timeout
        let all = monitor.pings.reversed()
        if all.isEmpty {
            sub.addItem(NSMenuItem(title: "No data yet", action: nil, keyEquivalent: ""))
        } else {
            let recentSet = Set(monitor.recentPings.map { $0.timestamp })
            for ping in all {
                let inWindow = recentSet.contains(ping.timestamp)
                let weight: NSFont.Weight = inWindow ? .bold : .regular
                let item = NSMenuItem()
                item.action = nil
                if let ms = ping.latency {
                    let text = String(format: "%.0f ms", ms)
                    var attrs: [NSAttributedString.Key: Any] = [
                        .font: NSFont.monospacedDigitSystemFont(ofSize: 13, weight: weight)
                    ]
                    if ms > pingThreshold { attrs[.foregroundColor] = NSColor.systemRed }
                    item.attributedTitle = NSAttributedString(string: text, attributes: attrs)
                } else {
                    item.attributedTitle = NSAttributedString(string: "✕ timeout", attributes: [
                        .foregroundColor: NSColor.systemRed,
                        .font: NSFont.monospacedDigitSystemFont(ofSize: 13, weight: weight)
                    ])
                }
                sub.addItem(item)
            }
        }
        historyItem.submenu = sub
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
