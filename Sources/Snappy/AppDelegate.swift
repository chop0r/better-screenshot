import AVFoundation
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var session: CaptureSession?
    private let thumbnail = ThumbnailController()
    private var editors: [EditorController] = []
    private var settings: SettingsController?
    private var captureItem: NSMenuItem?
    private var recordItem: NSMenuItem?
    private var recorder: ScreenRecorder?
    private var recordingPanel: RecordingPanel?
    private var recordingBusy = false
    private var videoWindows: [VideoWindowController] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        Settings.shared.applyLoginDefaultOnce()
        setupMainMenu()
        setupStatusItem()
        registerHotKey()
        NotificationCenter.default.addObserver(forName: Settings.changed, object: nil, queue: .main) { [weak self] _ in
            self?.setupMainMenu()
            self?.rebuildStatusMenu()
            self?.registerHotKey()
        }
        if !CGPreflightScreenCaptureAccess() { CGRequestScreenCaptureAccess() }
    }

    private func registerHotKey() {
        // One hotkey: opens the picker (Screenshot by default, Record via the toolbar) and stops a running recording.
        HotKey.shared.register(id: 1, code: Settings.shared.hotKeyCode, mods: Settings.shared.hotKeyMods) { [weak self] in
            if self?.recorder != nil { self?.stopRecording() } else { self?.startCapture() }
        }
        captureItem?.title = "\(tr("menu.capture")) (\(Settings.shared.hotKeyLabel))"
        recordItem?.title = recorder == nil ? tr("menu.record") : "\(tr("menu.stoprec")) (\(Settings.shared.hotKeyLabel))"
    }

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "camera.viewfinder", accessibilityDescription: "Better Screenshot")
        statusItem = item
        rebuildStatusMenu()
    }

    private func rebuildStatusMenu() {
        let menu = NSMenu()
        let cap = NSMenuItem(title: tr("menu.capture"), action: #selector(startCapture), keyEquivalent: "")
        cap.target = self
        captureItem = cap
        menu.addItem(cap)
        let rec = NSMenuItem(title: tr("menu.record"), action: #selector(toggleRecording), keyEquivalent: "")
        rec.target = self
        recordItem = rec
        menu.addItem(rec)
        let set = NSMenuItem(title: tr("menu.settings"), action: #selector(openSettings), keyEquivalent: ",")
        set.target = self
        menu.addItem(set)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: tr("menu.quit"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem?.menu = menu
        registerHotKey()
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
        add("Better Screenshot", [NSMenuItem(title: tr("menu.quit"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")])
        add(tr("menu.file"), [NSMenuItem(title: tr("ed.save"), action: Selector(("saveDocument:")), keyEquivalent: "s"),
                     NSMenuItem(title: tr("menu.close"), action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")])
        let redo = NSMenuItem(title: tr("menu.redo"), action: Selector(("redo:")), keyEquivalent: "z")
        redo.keyEquivalentModifierMask = [.command, .shift]
        add(tr("menu.edit"), [NSMenuItem(title: tr("menu.undo"), action: Selector(("undo:")), keyEquivalent: "z"), redo,
                       .separator(),
                       NSMenuItem(title: tr("menu.cut"), action: #selector(NSText.cut(_:)), keyEquivalent: "x"),
                       NSMenuItem(title: tr("ed.copy"), action: #selector(NSText.copy(_:)), keyEquivalent: "c"),
                       NSMenuItem(title: tr("menu.paste"), action: #selector(NSText.paste(_:)), keyEquivalent: "v"),
                       NSMenuItem(title: tr("menu.selectall"), action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")])
        NSApp.mainMenu = main
    }

    @objc func openSettings() {
        if settings == nil { settings = SettingsController() }
        settings?.show()
    }

    @objc func startCapture() {
        beginSession(.screenshot)
    }

    /// Starts the area/window/screen picker; for `.record` the chosen region starts a recording.
    private func beginSession(_ purpose: CapturePurpose) {
        guard session == nil, !recordingBusy, recorder == nil else { return }
        thumbnail.dismiss(animated: false)
        guard CGPreflightScreenCaptureAccess() else {
            CGRequestScreenCaptureAccess()
            alert(tr("alert.perm.title"), tr("alert.perm.text"))
            return
        }
        Task { @MainActor in
            do {
                let caps = try await CaptureService.captureAll()
                guard !caps.isEmpty else { return }
                let s = CaptureSession(captures: caps, windowFrames: CaptureService.visibleWindowFrames(), purpose: purpose)
                s.onFinish = { [weak self] result in
                    self?.session = nil
                    if let (image, screen) = result { self?.captured(image, on: screen) }
                }
                s.onRegion = { [weak self] result in
                    self?.session = nil
                    if let (screen, rect) = result { self?.beginRecording(on: screen, rect: rect) }
                }
                self.session = s
                s.start()
            } catch {
                self.alert(tr("alert.fail"), error.localizedDescription)
            }
        }
    }

    @objc func toggleRecording() {
        if recorder != nil {
            stopRecording()
        } else {
            beginSession(.record)
        }
    }

    private func recordingURL() -> URL {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd 'at' HH.mm.ss"
        let dir = (FileManager.default.urls(for: .moviesDirectory, in: .userDomainMask).first ?? FileManager.default.temporaryDirectory)
            .appendingPathComponent("Better Screenshot", isDirectory: true)
        return dir.appendingPathComponent("Recording \(f.string(from: Date())).mp4")
    }

    func beginRecording(on screen: NSScreen, rect viewRect: CGRect) {
        recordingBusy = true
        // Display-local rectangle in points with a top-left origin, as ScreenCaptureKit expects.
        let rect = CGRect(x: viewRect.minX, y: screen.frame.height - viewRect.maxY, width: viewRect.width, height: viewRect.height)
        let rec = ScreenRecorder()
        rec.onError = { [weak self] error in
            self?.stopRecording(failure: error)
        }
        Task { @MainActor in
            defer { self.recordingBusy = false }
            do {
                try await rec.start(screen: screen, rect: rect, url: self.recordingURL(),
                                    mic: Settings.shared.micOn, system: Settings.shared.systemAudioOn)
                self.recorder = rec
                let panel = RecordingPanel(screen: screen, recorder: rec) { [weak self] in self?.stopRecording() }
                panel.show()
                self.recordingPanel = panel
                self.setRecordingIndicator(true)
            } catch {
                self.alert(tr("rec.fail"), error.localizedDescription)
            }
        }
    }

    func stopRecording(failure: Error? = nil) {
        guard let rec = recorder else { return }
        recorder = nil
        recordingPanel?.close()
        recordingPanel = nil
        setRecordingIndicator(false)
        Task { @MainActor in
            let url = await rec.stop()
            if let url = url {
                self.recordingFinished(url)
            } else {
                self.alert(tr("rec.fail"), failure?.localizedDescription ?? "")
            }
        }
    }

    private func setRecordingIndicator(_ on: Bool) {
        let name = on ? "record.circle.fill" : "camera.viewfinder"
        statusItem?.button?.image = NSImage(systemSymbolName: name, accessibilityDescription: "Better Screenshot")
        statusItem?.button?.contentTintColor = on ? .systemRed : nil
        registerHotKey()
    }

    private func recordingFinished(_ url: URL) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects([url as NSURL])
        Task { @MainActor in
            let gen = AVAssetImageGenerator(asset: AVURLAsset(url: url))
            gen.appliesPreferredTrackTransform = true
            gen.maximumSize = CGSize(width: 960, height: 960)
            let screen = NSScreen.main ?? NSScreen.screens[0]
            guard let (image, _) = try? await gen.image(at: .zero) else {
                self.openVideo(url)
                return
            }
            self.thumbnail.show(image: image, screen: screen, corner: Settings.shared.corner,
                                seconds: Settings.shared.thumbnailSeconds, caption: tr("rec.saved")) { [weak self] in
                self?.openVideo(url)
            }
        }
    }

    private func openVideo(_ url: URL) {
        let c = VideoWindowController(url: url)
        c.onClose = { [weak self] ctrl in self?.videoWindows.removeAll { $0 === ctrl } }
        videoWindows.append(c)
        c.show()
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
