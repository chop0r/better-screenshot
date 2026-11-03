import AppKit
import Carbon.HIToolbox
import ServiceManagement

enum Corner: String, CaseIterable {
    case bottomLeft, bottomRight, topLeft, topRight

    var title: String { tr("corner.\(rawValue)") }
}

final class Settings {
    static let shared = Settings()
    static let changed = Notification.Name("SnappySettingsChanged")
    private let d = UserDefaults.standard

    var hotKeyCode: UInt32 {
        d.object(forKey: "hotKeyCode") == nil ? UInt32(kVK_ANSI_S) : UInt32(d.integer(forKey: "hotKeyCode"))
    }
    var hotKeyMods: UInt32 {
        d.object(forKey: "hotKeyMods") == nil ? UInt32(cmdKey | shiftKey) : UInt32(d.integer(forKey: "hotKeyMods"))
    }
    var hotKeyLabel: String { d.string(forKey: "hotKeyLabel") ?? "⇧⌘S" }

    func setHotKey(code: UInt32, mods: UInt32, label: String) {
        d.set(Int(code), forKey: "hotKeyCode")
        d.set(Int(mods), forKey: "hotKeyMods")
        d.set(label, forKey: "hotKeyLabel")
        NotificationCenter.default.post(name: Settings.changed, object: nil)
    }

    var micOn: Bool {
        get { d.bool(forKey: "recMic") }
        set { d.set(newValue, forKey: "recMic") }
    }

    var systemAudioOn: Bool {
        get { d.object(forKey: "recSystem") == nil ? true : d.bool(forKey: "recSystem") }
        set { d.set(newValue, forKey: "recSystem") }
    }

    var corner: Corner {
        get { Corner(rawValue: d.string(forKey: "corner") ?? "") ?? .bottomLeft }
        set { d.set(newValue.rawValue, forKey: "corner") }
    }

    /// UI language code (see `Lang.codes`); English unless the user picks another one.
    var language: String {
        get { d.string(forKey: "language") ?? "en" }
        set {
            d.set(newValue, forKey: "language")
            NotificationCenter.default.post(name: Settings.changed, object: nil)
        }
    }

    /// Start at login via the system login-items list (visible in System Settings → General → Login Items).
    var launchAtLogin: Bool {
        get { SMAppService.mainApp.status == .enabled }
        set {
            do {
                if newValue { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            } catch {
                NSLog("Login item change failed: \(error)")
            }
        }
    }

    /// Turns launch-at-login on once, on the very first run; afterwards the user's choice wins.
    func applyLoginDefaultOnce() {
        guard d.object(forKey: "loginDefaultApplied") == nil else { return }
        d.set(true, forKey: "loginDefaultApplied")
        launchAtLogin = true
    }

    var thumbnailSeconds: Double {
        get { d.object(forKey: "thumbSeconds") == nil ? 6 : d.double(forKey: "thumbSeconds") }
        set { d.set(newValue, forKey: "thumbSeconds") }
    }
}

func carbonModifiers(_ f: NSEvent.ModifierFlags) -> UInt32 {
    var m = 0
    if f.contains(.command) { m |= cmdKey }
    if f.contains(.shift) { m |= shiftKey }
    if f.contains(.option) { m |= optionKey }
    if f.contains(.control) { m |= controlKey }
    return UInt32(m)
}

func modifierLabel(_ f: NSEvent.ModifierFlags) -> String {
    var s = ""
    if f.contains(.control) { s += "⌃" }
    if f.contains(.option) { s += "⌥" }
    if f.contains(.shift) { s += "⇧" }
    if f.contains(.command) { s += "⌘" }
    return s
}
