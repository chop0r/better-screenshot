import AppKit

final class ThumbnailController {
    private var panel: NSPanel?
    private var timer: Timer?
    private var hovering = false

    func show(image: CGImage, screen: NSScreen, corner: Corner, seconds: Double, onOpen: @escaping () -> Void) {
        dismiss(animated: false)
        let scale = screen.backingScaleFactor
        let pw = CGFloat(image.width) / scale, ph = CGFloat(image.height) / scale
        let fit = min(240 / pw, 160 / ph, 1)
        let size = NSSize(width: max(80, (pw * fit).rounded()), height: max(50, (ph * fit).rounded()))

        let margin: CGFloat = 20
        let vis = screen.visibleFrame
        let left = corner == .bottomLeft || corner == .topLeft
        let x = left ? vis.minX + margin : vis.maxX - margin - size.width
        let y = (corner == .bottomLeft || corner == .bottomRight) ? vis.minY + margin : vis.maxY - margin - size.height
        let final = NSRect(origin: NSPoint(x: x, y: y), size: size)
        let startX = left ? vis.minX - size.width - 10 : vis.maxX + 10
        let start = NSRect(origin: NSPoint(x: startX, y: y), size: size)

        let p = NSPanel(contentRect: start, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        p.isFloatingPanel = true
        p.level = .statusBar
        p.backgroundColor = .clear
        p.isOpaque = false
        p.hasShadow = true
        p.hidesOnDeactivate = false
        p.isReleasedWhenClosed = false
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        let view = ThumbnailView(frame: NSRect(origin: .zero, size: size), image: image)
        view.onClick = { [weak self] in
            self?.dismiss(animated: false)
            onOpen()
        }
        view.onHover = { [weak self] inside in
            self?.hovering = inside
            if !inside { self?.scheduleDismiss(seconds: 2) }
        }
        p.contentView = view
        p.orderFrontRegardless()
        panel = p
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.28
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            p.animator().setFrame(final, display: true)
        }
        scheduleDismiss(seconds: seconds)
    }

    private func scheduleDismiss(seconds: Double) {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: seconds, repeats: false) { [weak self] _ in
            guard let self = self, !self.hovering else { return }
            self.dismiss(animated: true)
        }
    }

    func dismiss(animated: Bool) {
        timer?.invalidate()
        timer = nil
        hovering = false
        guard let p = panel else { return }
        panel = nil
        if animated {
            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = 0.2
                p.animator().alphaValue = 0
            }, completionHandler: { p.orderOut(nil) })
        } else {
            p.orderOut(nil)
        }
    }
}

final class ThumbnailView: NSView {
    var onClick: (() -> Void)?
    var onHover: ((Bool) -> Void)?
    private let label = NSTextField(labelWithString: tr("thumb.copied"))

    init(frame: NSRect, image: CGImage) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.contents = image
        layer?.contentsGravity = .resizeAspectFill
        layer?.cornerRadius = 10
        layer?.masksToBounds = true
        layer?.borderWidth = 1
        layer?.borderColor = NSColor.white.withAlphaComponent(0.4).cgColor
        label.font = .systemFont(ofSize: 11, weight: .medium)
        label.textColor = .white
        label.wantsLayer = true
        label.drawsBackground = true
        label.backgroundColor = NSColor.black.withAlphaComponent(0.6)
        label.alignment = .center
        label.frame = NSRect(x: 0, y: 0, width: frame.width, height: 20)
        label.autoresizingMask = [.width]
        addSubview(label)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func updateTrackingAreas() {
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(rect: .zero, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self))
    }

    override func mouseEntered(with event: NSEvent) {
        label.stringValue = tr("thumb.edit")
        onHover?(true)
    }

    override func mouseExited(with event: NSEvent) {
        label.stringValue = tr("thumb.copied")
        onHover?(false)
    }

    override func mouseDown(with event: NSEvent) { onClick?() }
}
