import AppKit
import Carbon.HIToolbox

final class HotKeyRecorder: NSButton {
    private var monitor: Any?

    override init(frame: NSRect) {
        super.init(frame: frame)
        bezelStyle = .rounded
        target = self
        action = #selector(toggle)
        title = Settings.shared.hotKeyLabel
    }

    required init?(coder: NSCoder) { fatalError() }

    @objc private func toggle() {
        if monitor != nil { stop(); return }
        title = tr("set.press")
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] e in
            guard let self = self else { return e }
            if e.keyCode == 53 { self.stop(); return nil }
            let flags = e.modifierFlags.intersection([.command, .shift, .option, .control])
            guard flags.contains(.command) || flags.contains(.control) || flags.contains(.option) else { return nil }
            var key = (e.charactersIgnoringModifiers ?? "").uppercased()
            if key == " " { key = "Space" }
            if key.isEmpty || key.unicodeScalars.first.map({ $0.value < 32 || $0.value > 0xF000 }) == true {
                key = "Key\(e.keyCode)"
            }
            Settings.shared.setHotKey(code: UInt32(e.keyCode), mods: carbonModifiers(flags),
                                      label: modifierLabel(flags) + key)
            self.stop()
            return nil
        }
    }

    private func stop() {
        if let m = monitor { NSEvent.removeMonitor(m) }
        monitor = nil
        title = Settings.shared.hotKeyLabel
    }
}

final class SettingsController: NSWindowController {
    private let durations: [Double] = [3, 6, 10, 15]
    private var corners = NSPopUpButton()
    private var seconds = NSPopUpButton()
    private var languages = NSPopUpButton()

    init() {
        let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 440, height: 250),
                         styleMask: [.titled, .closable], backing: .buffered, defer: false)
        w.isReleasedWhenClosed = false
        super.init(window: w)
        build()
    }

    required init?(coder: NSCoder) { fatalError() }

    /// Builds the form; called again after the language changes so every label follows it.
    private func build() {
        guard let w = window else { return }
        w.title = tr("set.title")
        corners = NSPopUpButton()
        seconds = NSPopUpButton()
        languages = NSPopUpButton()
        let loginBox = NSButton(checkboxWithTitle: tr("set.login"), target: self, action: #selector(loginChanged(_:)))
        loginBox.state = Settings.shared.launchAtLogin ? .on : .off

        corners.addItems(withTitles: Corner.allCases.map(\.title))
        corners.selectItem(at: Corner.allCases.firstIndex(of: Settings.shared.corner) ?? 0)
        corners.target = self
        corners.action = #selector(cornerChanged)

        seconds.addItems(withTitles: durations.map { String(format: tr("sec"), Int($0)) })
        seconds.selectItem(at: durations.firstIndex(of: Settings.shared.thumbnailSeconds) ?? 1)
        seconds.target = self
        seconds.action = #selector(secondsChanged)

        languages.addItems(withTitles: Lang.names)
        languages.selectItem(at: Lang.codes.firstIndex(of: Settings.shared.language) ?? 0)
        languages.target = self
        languages.action = #selector(languageChanged)

        let grid = NSGridView(views: [
            [NSTextField(labelWithString: tr("set.hotkey")), HotKeyRecorder(frame: .zero)],
            [NSTextField(labelWithString: tr("set.thumb")), corners],
            [NSTextField(labelWithString: tr("set.show")), seconds],
            [NSTextField(labelWithString: tr("set.lang")), languages],
            [NSGridCell.emptyContentView, loginBox],
        ])
        grid.rowSpacing = 12
        grid.columnSpacing = 12
        grid.column(at: 0).xPlacement = .trailing
        grid.translatesAutoresizingMaskIntoConstraints = false
        let content = NSView()
        content.addSubview(grid)
        NSLayoutConstraint.activate([
            grid.centerXAnchor.constraint(equalTo: content.centerXAnchor),
            grid.centerYAnchor.constraint(equalTo: content.centerYAnchor),
        ])
        w.contentView = content
    }

    @objc private func loginChanged(_ sender: NSButton) {
        Settings.shared.launchAtLogin = sender.state == .on
        sender.state = Settings.shared.launchAtLogin ? .on : .off
    }

    @objc private func cornerChanged() {
        Settings.shared.corner = Corner.allCases[corners.indexOfSelectedItem]
    }

    @objc private func secondsChanged() {
        Settings.shared.thumbnailSeconds = durations[seconds.indexOfSelectedItem]
    }

    @objc private func languageChanged() {
        Settings.shared.language = Lang.codes[languages.indexOfSelectedItem]
        build()
    }

    func show() {
        NSApp.activate(ignoringOtherApps: true)
        window?.center()
        showWindow(nil)
    }
}
