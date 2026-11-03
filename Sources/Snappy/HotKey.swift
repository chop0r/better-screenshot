import Carbon.HIToolbox

final class HotKey {
    static let shared = HotKey()
    var onPress: (() -> Void)?
    private var ref: EventHotKeyRef?
    private var handlerInstalled = false

    func register(code: UInt32, mods: UInt32) {
        if let r = ref {
            UnregisterEventHotKey(r)
            ref = nil
        }
        if !handlerInstalled {
            var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
            InstallEventHandler(GetApplicationEventTarget(), { _, _, _ in
                HotKey.shared.onPress?()
                return noErr
            }, 1, &spec, nil, nil)
            handlerInstalled = true
        }
        let id = EventHotKeyID(signature: OSType(0x534E4150), id: 1)
        RegisterEventHotKey(code, mods, id, GetApplicationEventTarget(), 0, &ref)
    }
}
