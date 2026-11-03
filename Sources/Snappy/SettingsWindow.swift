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
        title = "Нажмите сочетание…"
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
    private let corners = NSPopUpButton()
    private let seconds = NSPopUpButton()
    private let durations: [Double] = [3, 6, 10, 15]

    init() {
        let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 420, height: 170),
                         styleMask: [.titled, .closable], backing: .buffered, defer: false)
        w.title = "Настройки Better Screenshot"
        w.isReleasedWhenClosed = false
        super.init(window: w)

        corners.addItems(withTitles: Corner.allCases.map(\.title))
        corners.selectItem(at: Corner.allCases.firstIndex(of: Settings.shared.corner) ?? 0)
        corners.target = self
        corners.action = #selector(cornerChanged)

        seconds.addItems(withTitles: durations.map { "\(Int($0)) сек" })
        seconds.selectItem(at: durations.firstIndex(of: Settings.shared.thumbnailSeconds) ?? 1)
        seconds.target = self
        seconds.action = #selector(secondsChanged)

        let grid = NSGridView(views: [
            [NSTextField(labelWithString: "Горячая клавиша:"), HotKeyRecorder(frame: .zero)],
            [NSTextField(labelWithString: "Миниатюра:"), corners],
            [NSTextField(labelWithString: "Показывать:"), seconds],
        ])
        grid.rowSpacing = 12
        grid.columnSpacing = 12
        grid.column(at: 0).xPlacement = .trailing
        grid.translatesAutoresizingMaskIntoConstraints = false
        w.contentView?.addSubview(grid)
        NSLayoutConstraint.activate([
            grid.centerXAnchor.constraint(equalTo: w.contentView!.centerXAnchor),
            grid.centerYAnchor.constraint(equalTo: w.contentView!.centerYAnchor),
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    @objc private func cornerChanged() {
        Settings.shared.corner = Corner.allCases[corners.indexOfSelectedItem]
    }

    @objc private func secondsChanged() {
        Settings.shared.thumbnailSeconds = durations[seconds.indexOfSelectedItem]
    }

    func show() {
        NSApp.activate(ignoringOtherApps: true)
        window?.center()
        showWindow(nil)
    }
}
