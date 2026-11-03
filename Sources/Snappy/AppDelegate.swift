import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var session: CaptureSession?
    private let thumbnail = ThumbnailController()
    private var editors: [EditorController] = []
    private var settings: SettingsController?
    private var captureItem: NSMenuItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMainMenu()
        setupStatusItem()
        HotKey.shared.onPress = { [weak self] in self?.startCapture() }
        registerHotKey()
        NotificationCenter.default.addObserver(forName: Settings.changed, object: nil, queue: .main) { [weak self] _ in
            self?.registerHotKey()
        }
        if !CGPreflightScreenCaptureAccess() { CGRequestScreenCaptureAccess() }
    }

    private func registerHotKey() {
        HotKey.shared.register(code: Settings.shared.hotKeyCode, mods: Settings.shared.hotKeyMods)
        captureItem?.title = "Сделать снимок (\(Settings.shared.hotKeyLabel))"
    }

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "camera.viewfinder", accessibilityDescription: "Better Screenshot")
        let menu = NSMenu()
        let cap = NSMenuItem(title: "Сделать снимок", action: #selector(startCapture), keyEquivalent: "")
        cap.target = self
        captureItem = cap
        menu.addItem(cap)
        let set = NSMenuItem(title: "Настройки…", action: #selector(openSettings), keyEquivalent: ",")
        set.target = self
        menu.addItem(set)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Выйти", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        item.menu = menu
        statusItem = item
    }

    /// An accessory app has no visible menu bar, but key equivalents (⌘Z, ⌘C, ⌘S) still need these items.
    private func setupMainMenu() {
        let main = NSMenu()
        func add(_ title: String, _ items: [NSMenuItem]) {
            let top = NSMenuItem()
            let m = NSMenu(title: title)
            items.forEach(m.addItem)
            top.submenu = m
            main.addItem(top)
        }
        add("Better Screenshot", [NSMenuItem(title: "Выйти", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")])
        add("Файл", [NSMenuItem(title: "Сохранить…", action: Selector(("saveDocument:")), keyEquivalent: "s"),
                     NSMenuItem(title: "Закрыть", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")])
        let redo = NSMenuItem(title: "Вернуть", action: Selector(("redo:")), keyEquivalent: "z")
        redo.keyEquivalentModifierMask = [.command, .shift]
        add("Правка", [NSMenuItem(title: "Отменить", action: Selector(("undo:")), keyEquivalent: "z"), redo,
                       .separator(),
                       NSMenuItem(title: "Вырезать", action: #selector(NSText.cut(_:)), keyEquivalent: "x"),
                       NSMenuItem(title: "Копировать", action: #selector(NSText.copy(_:)), keyEquivalent: "c"),
                       NSMenuItem(title: "Вставить", action: #selector(NSText.paste(_:)), keyEquivalent: "v"),
                       NSMenuItem(title: "Выделить всё", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")])
        NSApp.mainMenu = main
    }

    @objc func openSettings() {
        if settings == nil { settings = SettingsController() }
        settings?.show()
    }

    @objc func startCapture() {
        guard session == nil else { return }
        thumbnail.dismiss(animated: false)
        guard CGPreflightScreenCaptureAccess() else {
            CGRequestScreenCaptureAccess()
            alert("Нужен доступ к записи экрана",
                  "Откройте Системные настройки → Конфиденциальность и безопасность → Запись экрана, включите Better Screenshot и перезапустите приложение.")
            return
        }
        Task { @MainActor in
            do {
                let caps = try await CaptureService.captureAll()
                guard !caps.isEmpty else { return }
                let s = CaptureSession(captures: caps, windowFrames: CaptureService.visibleWindowFrames())
                s.onFinish = { [weak self] result in
                    self?.session = nil
                    if let (image, screen) = result { self?.captured(image, on: screen) }
                }
                self.session = s
                s.start()
            } catch {
                self.alert("Не удалось сделать снимок", error.localizedDescription)
            }
        }
    }

    private func captured(_ image: CGImage, on screen: NSScreen) {
        let scale = screen.backingScaleFactor
        Clipboard.copy(image, scale: scale)
        thumbnail.show(image: image, screen: screen, corner: Settings.shared.corner,
                       seconds: Settings.shared.thumbnailSeconds) { [weak self] in
            self?.openEditor(image, scale: scale)
        }
    }

    private func openEditor(_ image: CGImage, scale: CGFloat) {
        let c = EditorController(image: image, scale: scale)
        c.onClose = { [weak self] ctrl in self?.editors.removeAll { $0 === ctrl } }
        editors.append(c)
        c.show()
    }

    private func alert(_ title: String, _ text: String) {
        NSApp.activate(ignoringOtherApps: true)
        let a = NSAlert()
        a.messageText = title
        a.informativeText = text
        a.runModal()
    }
}
