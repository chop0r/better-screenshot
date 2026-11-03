import Carbon.HIToolbox

/// Global hotkeys (Carbon). Each hotkey has an id; `handlers[id]` runs when it is pressed.
final class HotKey {
    static let shared = HotKey()
    var handlers: [UInt32: () -> Void] = [:]
    private var refs: [UInt32: EventHotKeyRef] = [:]
    private var handlerInstalled = false

    func register(id: UInt32, code: UInt32, mods: UInt32, handler: @escaping () -> Void) {
        if let r = refs[id] {
            UnregisterEventHotKey(r)
            refs[id] = nil
        }
        handlers[id] = handler
        if !handlerInstalled {
            var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
            InstallEventHandler(GetApplicationEventTarget(), { _, event, _ in
                var hk = EventHotKeyID()
                GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil,
                                  MemoryLayout<EventHotKeyID>.size, nil, &hk)
                HotKey.shared.handlers[hk.id]?()
                return noErr
            }, 1, &spec, nil, nil)
            handlerInstalled = true
        }
        var ref: EventHotKeyRef?
        RegisterEventHotKey(code, mods, EventHotKeyID(signature: OSType(0x534E4150), id: id), GetApplicationEventTarget(), 0, &ref)
        refs[id] = ref
    }
}
