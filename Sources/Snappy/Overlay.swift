import AppKit

enum CaptureMode: Int {
    case area, window, screen
}

final class OverlayWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

final class CaptureSession {
    let captures: [Capture]
    let windowFrames: [CGRect]
    var onFinish: (((CGImage, NSScreen)?) -> Void)?
    private var windows: [OverlayWindow] = []
    private var views: [OverlayView] = []
    weak var segmented: NSSegmentedControl?

    var mode: CaptureMode = .area {
        didSet {
            segmented?.selectedSegment = mode.rawValue
            views.forEach { $0.modeChanged() }
        }
    }

    init(captures: [Capture], windowFrames: [CGRect]) {
        self.captures = captures
        self.windowFrames = windowFrames
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
    }
}

final class OverlayView: NSView {
    unowned let session: CaptureSession
    let capture: Capture
    private let nsImage: NSImage
    private var dragStart: NSPoint?
    private var dragRect: NSRect?
    private var hover: NSRect?

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
        let stack = NSStackView(views: [seg, hint])
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
        box.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            box.centerXAnchor.constraint(equalTo: centerXAnchor),
            box.topAnchor.constraint(equalTo: topAnchor, constant: 70),
        ])
        session.segmented = seg
    }

    @objc private func modeChanged(_ sender: NSSegmentedControl) {
        session.mode = CaptureMode(rawValue: sender.selectedSegment) ?? .area
    }

    func modeChanged() {
        dragStart = nil
        dragRect = nil
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
                needsDisplay = true
            }
        case .window, .screen:
            if let h = hover { session.finish(rect: h, in: self) }
        }
    }

    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 53: session.cancel()
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
        NSColor.controlAccentColor.setStroke()
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
