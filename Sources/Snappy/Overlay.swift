import AppKit

enum CaptureMode: Int {
    case area, window, screen
}

final class OverlayWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

enum CapturePurpose {
    case screenshot, text, record
}

final class CaptureSession {
    let captures: [Capture]
    let windowFrames: [CGRect]
    /// Switchable in the toolbar (or with S / R) while the picker is open.
    var purpose: CapturePurpose {
        didSet { views.forEach { $0.purposeChanged() } }
    }
    var onFinish: (((CGImage, NSScreen)?) -> Void)?
    /// Record mode: the chosen region (view coordinates of that screen, bottom-left origin) or nil when cancelled.
    var onRegion: (((NSScreen, CGRect)?) -> Void)?
    private var windows: [OverlayWindow] = []
    private var views: [OverlayView] = []
    weak var segmented: NSSegmentedControl?
    weak var purposeSegmented: NSSegmentedControl?

    var mode: CaptureMode = .area {
        didSet {
            segmented?.selectedSegment = mode.rawValue
            views.forEach { $0.modeChanged() }
        }
    }

    init(captures: [Capture], windowFrames: [CGRect], purpose: CapturePurpose = .screenshot) {
        self.captures = captures
        self.windowFrames = windowFrames
        self.purpose = purpose
    }

    func start() {
        let mouse = NSEvent.mouseLocation
        for cap in captures {
            let w = OverlayWindow(contentRect: cap.screen.frame, styleMask: .borderless, backing: .buffered, defer: false)
            w.level = .screenSaver
            w.isOpaque = true
            w.hasShadow = false
            w.backgroundColor = .black
            w.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            w.isReleasedWhenClosed = false
            let v = OverlayView(session: self, capture: cap)
            w.contentView = v
            w.setFrame(cap.screen.frame, display: true)
            if cap.screen.frame.contains(mouse) { v.installToolbar() }
            windows.append(w)
            views.append(v)
        }
        NSApp.activate(ignoringOtherApps: true)
        let key = windows.first(where: { $0.frame.contains(mouse) }) ?? windows.first
        for w in windows { w.orderFrontRegardless() }
        key?.makeKeyAndOrderFront(nil)
        if let v = key?.contentView { key?.makeFirstResponder(v) }
        views.forEach { $0.updateHover(at: mouse) }
        NSCursor.crosshair.set()
    }

    private func close() {
        windows.forEach { $0.orderOut(nil) }
        windows.removeAll()
        views.removeAll()
    }

    func finish(rect: CGRect, in view: OverlayView) {
        let cap = view.capture
        if purpose == .record {
            close()
            onRegion?((cap.screen, rect))
            return
        }
        let scale = CGFloat(cap.image.width) / cap.screen.frame.width
        let px = CGRect(x: rect.minX * scale,
                        y: (cap.screen.frame.height - rect.maxY) * scale,
                        width: rect.width * scale,
                        height: rect.height * scale).integral
        let cropped = cap.image.cropping(to: px)
        close()
        if let cropped = cropped { onFinish?((cropped, cap.screen)) } else { onFinish?(nil) }
    }

    func cancel() {
        close()
        onFinish?(nil)
        onRegion?(nil)
    }
}

final class OverlayView: NSView {
    unowned let session: CaptureSession
    let capture: Capture
    private let nsImage: NSImage
    private var dragStart: NSPoint?
    private var dragRect: NSRect?
    private var hover: NSRect?
    private var toolbarBox: NSView?

    init(session: CaptureSession, capture: Capture) {
        self.session = session
        self.capture = capture
        self.nsImage = NSImage(cgImage: capture.image, size: capture.screen.frame.size)
        super.init(frame: NSRect(origin: .zero, size: capture.screen.frame.size))
    }

    required init?(coder: NSCoder) { fatalError() }

    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    func installToolbar() {
        let seg = NSSegmentedControl(labels: [tr("mode.area"), tr("mode.window"), tr("mode.screen")], trackingMode: .selectOne,
                                     target: self, action: #selector(modeChanged(_:)))
        seg.selectedSegment = session.mode.rawValue
        seg.segmentStyle = .rounded
        let hint = NSTextField(labelWithString: tr("esc.cancel"))
        hint.textColor = .secondaryLabelColor
        hint.font = .systemFont(ofSize: 11)
        let purposeSeg = NSSegmentedControl(labels: [tr("purpose.shot"), tr("purpose.text"), tr("purpose.rec")], trackingMode: .selectOne,
                                            target: self, action: #selector(purposeClicked(_:)))
        purposeSeg.selectedSegment = Self.purposeIndex(session.purpose)
        purposeSeg.segmentStyle = .rounded
        session.purposeSegmented = purposeSeg
        do {
            let mic = ToggleIconButton(on: "mic.fill", off: "mic.slash.fill", tip: tr("rec.mic"), isOn: Settings.shared.micOn)
            mic.onToggle = { Settings.shared.micOn = $0 }
            let sys = ToggleIconButton(on: "speaker.wave.2.fill", off: "speaker.slash.fill", tip: tr("rec.sys"), isOn: Settings.shared.systemAudioOn)
            sys.onToggle = { Settings.shared.systemAudioOn = $0 }
            micButton = mic
            sysButton = sys
        }
        micButton?.isHidden = session.purpose != .record
        sysButton?.isHidden = session.purpose != .record
        let stack = NSStackView(views: [purposeSeg, seg] + [micButton, sysButton].compactMap { $0 } + [hint])
        stack.orientation = .horizontal
        stack.spacing = 14
        stack.edgeInsets = NSEdgeInsets(top: 10, left: 16, bottom: 10, right: 16)
        let box = NSVisualEffectView()
        box.material = .hudWindow
        box.state = .active
        box.wantsLayer = true
        box.layer?.cornerRadius = 12
        box.layer?.masksToBounds = true
        box.addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: box.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: box.trailingAnchor),
            stack.topAnchor.constraint(equalTo: box.topAnchor),
            stack.bottomAnchor.constraint(equalTo: box.bottomAnchor),
        ])
        addSubview(box)
        toolbarBox = box
        box.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            box.centerXAnchor.constraint(equalTo: centerXAnchor),
            box.topAnchor.constraint(equalTo: topAnchor, constant: 70),
        ])
        session.segmented = seg
    }

    /// Fades the toolbar out while an area is being dragged, so nothing behind it is hidden.
    private func setToolbarHidden(_ hidden: Bool) {
        guard let box = toolbarBox, (box.alphaValue < 0.5) != hidden else { return }
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.12
            box.animator().alphaValue = hidden ? 0 : 1
        }
    }

    private var micButton: NSView?
    private var sysButton: NSView?

    private static func purposeIndex(_ p: CapturePurpose) -> Int {
        switch p {
        case .screenshot: return 0
        case .text: return 1
        case .record: return 2
        }
    }

    @objc private func purposeClicked(_ sender: NSSegmentedControl) {
        session.purpose = [.screenshot, .text, .record][max(0, min(2, sender.selectedSegment))]
    }

    func purposeChanged() {
        session.purposeSegmented?.selectedSegment = Self.purposeIndex(session.purpose)
        micButton?.isHidden = session.purpose != .record
        sysButton?.isHidden = session.purpose != .record
        needsDisplay = true
    }

    @objc private func modeChanged(_ sender: NSSegmentedControl) {
        session.mode = CaptureMode(rawValue: sender.selectedSegment) ?? .area
    }

    func modeChanged() {
        dragStart = nil
        dragRect = nil
        setToolbarHidden(false)
        updateHover(at: NSEvent.mouseLocation)
        window?.invalidateCursorRects(for: self)
        needsDisplay = true
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: session.mode == .area ? .crosshair : .pointingHand)
    }

    override func updateTrackingAreas() {
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(rect: .zero, options: [.mouseMoved, .activeAlways, .inVisibleRect], owner: self))
    }

    func updateHover(at global: NSPoint) {
        let origin = capture.screen.frame.origin
        switch session.mode {
        case .area:
            hover = nil
        case .window:
            if capture.screen.frame.contains(global),
               let f = session.windowFrames.first(where: { $0.contains(global) }) {
                hover = f.intersection(capture.screen.frame).offsetBy(dx: -origin.x, dy: -origin.y)
            } else {
                hover = nil
            }
        case .screen:
            hover = capture.screen.frame.contains(global) ? bounds : nil
        }
        needsDisplay = true
    }

    override func mouseMoved(with event: NSEvent) {
        updateHover(at: NSEvent.mouseLocation)
    }

    private func rect(_ a: NSPoint, _ b: NSPoint) -> NSRect {
        NSRect(x: min(a.x, b.x), y: min(a.y, b.y), width: abs(a.x - b.x), height: abs(a.y - b.y))
    }

    override func mouseDown(with event: NSEvent) {
        guard session.mode == .area else { return }
        dragStart = convert(event.locationInWindow, from: nil)
        dragRect = nil
    }

    override func mouseDragged(with event: NSEvent) {
        guard session.mode == .area, let s = dragStart else { return }
        dragRect = rect(s, convert(event.locationInWindow, from: nil))
        if let r = dragRect, r.width > 3 || r.height > 3 { setToolbarHidden(true) }
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        switch session.mode {
        case .area:
            if let r = dragRect, r.width > 4, r.height > 4 {
                session.finish(rect: r, in: self)
            } else {
                dragStart = nil
                dragRect = nil
                setToolbarHidden(false)
                needsDisplay = true
            }
        case .window, .screen:
            if let h = hover { session.finish(rect: h, in: self) }
        }
    }

    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 53: session.cancel()
        case 1: session.purpose = .screenshot
        case 15: session.purpose = .record
        case 17: session.purpose = .text
        case 18: session.mode = .area
        case 19: session.mode = .window
        case 20: session.mode = .screen
        default: super.keyDown(with: event)
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        nsImage.draw(in: bounds)
        let highlight = session.mode == .area ? dragRect : hover
        NSColor.black.withAlphaComponent(0.45).setFill()
        let dim = NSBezierPath(rect: bounds)
        if let r = highlight {
            dim.appendRect(r)
            dim.windingRule = .evenOdd
        }
        dim.fill()
        guard let r = highlight else { return }
        (session.purpose == .record ? NSColor.systemRed
            : session.purpose == .text ? NSColor.systemGreen : NSColor.controlAccentColor).setStroke()
        let border = NSBezierPath(rect: r.insetBy(dx: 0.5, dy: 0.5))
        border.lineWidth = 2
        border.stroke()
        if session.mode == .area {
            let text = "\(Int(r.width)) × \(Int(r.height))" as NSString
            let attrs: [NSAttributedString.Key: Any] = [.font: NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .medium),
                                                        .foregroundColor: NSColor.white]
            let size = text.size(withAttributes: attrs)
            let pill = NSRect(x: r.minX, y: min(r.maxY + 6, bounds.height - size.height - 8),
                              width: size.width + 12, height: size.height + 4)
            NSColor.black.withAlphaComponent(0.7).setFill()
            NSBezierPath(roundedRect: pill, xRadius: 5, yRadius: 5).fill()
            text.draw(at: NSPoint(x: pill.minX + 6, y: pill.minY + 2), withAttributes: attrs)
        }
    }
}
