import AppKit
import Carbon.HIToolbox

enum Corner: String, CaseIterable {
    case bottomLeft, bottomRight, topLeft, topRight

    var title: String {
        switch self {
        case .bottomLeft: return "Снизу слева"
        case .bottomRight: return "Снизу справа"
        case .topLeft: return "Сверху слева"
        case .topRight: return "Сверху справа"
        }
    }
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

    var corner: Corner {
        get { Corner(rawValue: d.string(forKey: "corner") ?? "") ?? .bottomLeft }
        set { d.set(newValue.rawValue, forKey: "corner") }
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
