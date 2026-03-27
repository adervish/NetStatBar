import AppKit

class PreferencesWindowController: NSWindowController {
    static let shared = PreferencesWindowController()

    private var hostField: NSTextField!
    private var intervalField: NSTextField!
    private var maxPingsField: NSTextField!
    private var menuBarCheck: NSButton!

    private init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 340, height: 236),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "NetStatBar Preferences"
        window.isReleasedWhenClosed = false
        super.init(window: window)
        buildUI()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func buildUI() {
        let content = NSView(frame: NSRect(x: 0, y: 0, width: 340, height: 236))

        // Show in menu bar
        menuBarCheck = NSButton(checkboxWithTitle: "Show in menu bar", target: nil, action: nil)
        menuBarCheck.frame = NSRect(x: 132, y: 192, width: 200, height: 22)

        // Ping target
        let hostLabel = NSTextField(labelWithString: "Ping target:")
        hostLabel.frame = NSRect(x: 16, y: 158, width: 108, height: 22)
        hostLabel.alignment = .right

        hostField = NSTextField(frame: NSRect(x: 132, y: 158, width: 188, height: 22))
        hostField.placeholderString = "1.1.1.1"

        // Interval
        let intervalLabel = NSTextField(labelWithString: "Interval (seconds):")
        intervalLabel.frame = NSRect(x: 16, y: 122, width: 108, height: 22)
        intervalLabel.alignment = .right

        intervalField = NSTextField(frame: NSRect(x: 132, y: 122, width: 80, height: 22))
        intervalField.placeholderString = "1"

        let intervalNote = NSTextField(labelWithString: "minimum 0.5")
        intervalNote.frame = NSRect(x: 218, y: 124, width: 110, height: 18)
        intervalNote.font = .systemFont(ofSize: 11)
        intervalNote.textColor = .secondaryLabelColor

        // Max stored pings
        let maxPingsLabel = NSTextField(labelWithString: "Max stored pings:")
        maxPingsLabel.frame = NSRect(x: 16, y: 86, width: 108, height: 22)
        maxPingsLabel.alignment = .right

        maxPingsField = NSTextField(frame: NSRect(x: 132, y: 86, width: 80, height: 22))
        maxPingsField.placeholderString = "unlimited"

        let maxPingsNote = NSTextField(labelWithString: "pruned every 100")
        maxPingsNote.frame = NSRect(x: 218, y: 88, width: 110, height: 18)
        maxPingsNote.font = .systemFont(ofSize: 11)
        maxPingsNote.textColor = .secondaryLabelColor

        // Database link
        let dbLabel = NSTextField(labelWithString: "Database:")
        dbLabel.frame = NSRect(x: 16, y: 54, width: 108, height: 22)
        dbLabel.alignment = .right

        let dbLink = NSButton(title: "Show in Finder", target: self, action: #selector(showDatabaseInFinder))
        dbLink.frame = NSRect(x: 130, y: 52, width: 130, height: 22)
        dbLink.bezelStyle = .inline
        dbLink.isBordered = false
        dbLink.attributedTitle = NSAttributedString(
            string: "Show in Finder",
            attributes: [.foregroundColor: NSColor.linkColor,
                         .font: NSFont.systemFont(ofSize: 13),
                         .underlineStyle: NSUnderlineStyle.single.rawValue]
        )

        // Buttons
        let cancelBtn = NSButton(title: "Cancel", target: self, action: #selector(cancel))
        cancelBtn.frame = NSRect(x: 148, y: 16, width: 80, height: 28)
        cancelBtn.keyEquivalent = "\u{1B}"

        let saveBtn = NSButton(title: "Save", target: self, action: #selector(save))
        saveBtn.frame = NSRect(x: 240, y: 16, width: 80, height: 28)
        saveBtn.bezelStyle = .rounded
        saveBtn.keyEquivalent = "\r"

        [menuBarCheck, hostLabel, hostField, intervalLabel, intervalField,
         intervalNote, maxPingsLabel, maxPingsField, maxPingsNote,
         dbLabel, dbLink, cancelBtn, saveBtn].forEach { content.addSubview($0) }

        window?.contentView = content
    }

    func open() {
        let showInMenuBar = UserDefaults.standard.object(forKey: "showInMenuBar") as? Bool ?? true
        menuBarCheck.state = showInMenuBar ? .on : .off

        hostField.stringValue = UserDefaults.standard.string(forKey: "pingHost") ?? "1.1.1.1"
        let interval = UserDefaults.standard.double(forKey: "pingInterval")
        intervalField.stringValue = interval > 0 ? String(format: "%g", interval) : "1"
        let maxPings = UserDefaults.standard.integer(forKey: "maxStoredPings")
        maxPingsField.stringValue = maxPings > 0 ? "\(maxPings)" : ""

        showWindow(nil)
        window?.center()
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func showDatabaseInFinder() {
        let appSupport = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dbURL = appSupport.appendingPathComponent("NetStatBar/measurements.db")
        if FileManager.default.fileExists(atPath: dbURL.path) {
            NSWorkspace.shared.activateFileViewerSelecting([dbURL])
        } else {
            NSWorkspace.shared.activateFileViewerSelecting([dbURL.deletingLastPathComponent()])
        }
    }

    @objc private func cancel() { window?.close() }

    @objc private func save() {
        let host = hostField.stringValue.trimmingCharacters(in: .whitespaces)
        let interval = max(0.5, Double(intervalField.stringValue) ?? 1.0)
        let maxPingsStr = maxPingsField.stringValue.trimmingCharacters(in: .whitespaces)
        let maxPings = maxPingsStr.isEmpty ? 0 : max(100, Int(maxPingsStr) ?? 0)
        let showInMenuBar = menuBarCheck.state == .on

        UserDefaults.standard.set(host.isEmpty ? "1.1.1.1" : host, forKey: "pingHost")
        UserDefaults.standard.set(interval, forKey: "pingInterval")
        UserDefaults.standard.set(maxPings, forKey: "maxStoredPings")
        UserDefaults.standard.set(showInMenuBar, forKey: "showInMenuBar")

        NetworkMonitor.shared.restartTimers()
        (NSApp.delegate as? AppDelegate)?.applyMenuBarVisibility()
        window?.close()
    }
}
