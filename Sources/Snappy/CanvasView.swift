import AppKit

enum Tool: Int, CaseIterable {
    case select, pen, highlighter, line, arrow, rect, ellipse, text, number, mosaic, crop

    var symbol: String {
        switch self {
        case .select: return "cursorarrow"
        case .pen: return "pencil.tip"
        case .highlighter: return "highlighter"
        case .line: return "line.diagonal"
        case .arrow: return "arrow.up.right"
        case .rect: return "rectangle"
        case .ellipse: return "circle"
        case .text: return "textformat"
        case .number: return "1.circle"
        case .mosaic: return "squareshape.split.3x3"
        case .crop: return "crop"
        }
    }

    var title: String { tr("tool.\(self)") }
}

final class CanvasView: NSView, NSTextFieldDelegate {
    let doc: EditorDocument
    var tool: Tool = .pen {
        didSet {
            endText()
            selectedID = nil
            cropRect = nil
            window?.invalidateCursorRects(for: self)
            needsDisplay = true
        }
    }
    var color: NSColor = .systemRed
    var sizeIndex = 1
    var smart = true
    var onCopy: (() -> Void)?
    var onSave: (() -> Void)?
    var onClose: (() -> Void)?

    private var draft: Item?
    private var dragStart: CGPoint?
    private var selectedID: UUID?
    private var moveOrigin: EditorState?
    private var moved = false
    private var dragShiftActive = false
    private var cropRect: CGRect?
    private var textField: NSTextField?
    private var textOrigin: CGPoint = .zero
    private var textSizePx: CGFloat = 0
    private var textColor: NSColor = .red
    private var editingID: UUID?

    init(doc: EditorDocument) {
        self.doc = doc
        super.init(frame: .zero)
        doc.onChange = { [weak self] in self?.needsDisplay = true }
    }

    required init?(coder: NSCoder) { fatalError() }

    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    // MARK: geometry

    private var imageSize: CGSize { CGSize(width: doc.state.image.width, height: doc.state.image.height) }

    private var metrics: (s: CGFloat, origin: CGPoint) {
        let avail = bounds.insetBy(dx: 24, dy: 24)
        let sz = imageSize
        let s = max(0.01, min(avail.width / sz.width, avail.height / sz.height, 2 / doc.unit))
        let origin = CGPoint(x: bounds.midX - sz.width * s / 2, y: bounds.midY - sz.height * s / 2)
        return (s, origin)
    }

    private func toImage(_ e: NSEvent) -> CGPoint {
        let p = convert(e.locationInWindow, from: nil)
        let m = metrics
        return CGPoint(x: (p.x - m.origin.x) / m.s, y: (p.y - m.origin.y) / m.s)
    }

    // MARK: style helpers

    private var lineWidth: CGFloat { 4 * doc.unit * [0.6, 1, 1.8][sizeIndex] }
    private var textSize: CGFloat { 15 * doc.unit * [0.9, 1.2, 1.7][sizeIndex] }

    private func makeItem(_ shape: Shape) -> Item {
        switch tool {
        case .highlighter:
            return Item(shape: shape, color: color, width: lineWidth * 3.5, opacity: 0.4, highlighter: true)
        case .mosaic:
            return Item(shape: shape, color: color, width: 9 * doc.unit)
        default:
            return Item(shape: shape, color: color, width: lineWidth)
        }
    }

    // MARK: drawing

    override func draw(_ dirtyRect: NSRect) {
        NSColor(white: 0.14, alpha: 1).setFill()
        bounds.fill()
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        let m = metrics
        let sz = imageSize
        ctx.saveGState()
        ctx.translateBy(x: m.origin.x, y: m.origin.y)
        ctx.scaleBy(x: m.s, y: m.s)
        ctx.setShadow(offset: .zero, blur: 12, color: NSColor.black.withAlphaComponent(0.5).cgColor)
        ctx.setFillColor(NSColor.black.cgColor)
        ctx.fill(CGRect(origin: .zero, size: sz))
        ctx.setShadow(offset: .zero, blur: 0, color: nil)
        ctx.clip(to: CGRect(origin: .zero, size: sz))
        var shown = doc.state
        if let id = editingID { shown.items.removeAll { $0.id == id } }
        Renderer.draw(shown, extra: draft, in: ctx, unit: doc.unit)

        if let id = selectedID, let item = doc.state.items.first(where: { $0.id == id }) {
            ctx.setStrokeColor(NSColor.controlAccentColor.cgColor)
            ctx.setLineWidth(1.5 / m.s)
            ctx.setLineDash(phase: 0, lengths: [5 / m.s, 4 / m.s])
            ctx.stroke(item.bounds.insetBy(dx: -4 / m.s, dy: -4 / m.s))
        }
        if let r = cropRect?.standardized {
            ctx.setFillColor(NSColor.black.withAlphaComponent(0.55).cgColor)
            let path = CGMutablePath()
            path.addRect(CGRect(origin: .zero, size: sz))
            path.addRect(r)
            ctx.addPath(path)
            ctx.fillPath(using: .evenOdd)
            ctx.setStrokeColor(NSColor.white.cgColor)
            ctx.setLineWidth(1.5 / m.s)
            ctx.stroke(r)
        }
        ctx.restoreGState()
    }

    override func resetCursorRects() {
        switch tool {
        case .select: addCursorRect(bounds, cursor: .arrow)
        case .text: addCursorRect(bounds, cursor: .iBeam)
        default: addCursorRect(bounds, cursor: .crosshair)
        }
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        window?.invalidateCursorRects(for: self)
    }

    // MARK: mouse

    override func mouseDown(with e: NSEvent) {
        window?.makeFirstResponder(self)
        let p = toImage(e)
        dragStart = p
        moved = false
        switch tool {
        case .select:
            let tol = 6 / metrics.s
            selectedID = doc.state.items.last(where: { $0.hit(p, tolerance: tol) })?.id
            moveOrigin = selectedID == nil ? nil : doc.state
            if e.clickCount == 2, let id = selectedID,
               let item = doc.state.items.first(where: { $0.id == id }), case .text = item.shape {
                moveOrigin = nil
                beginText(at: p, editing: item)
            }
        case .pen, .highlighter:
            draft = makeItem(.freehand([p]))
        case .text:
            let tol = 6 / metrics.s
            let existing = doc.state.items.last(where: {
                if case .text = $0.shape { return $0.hit(p, tolerance: tol) }
                return false
            })
            beginText(at: p, editing: existing)
        case .number:
            var st = doc.state
            let next = (st.items.compactMap { item -> Int? in
                if case .number(_, let v, _) = item.shape { return v }
                return nil
            }.max() ?? 0) + 1
            let size = 11 * doc.unit * [0.9, 1.2, 1.7][sizeIndex]
            st.items.append(makeItem(.number(center: p, value: next, size: size)))
            doc.commit(st)
        case .crop:
            cropRect = nil
        default:
            break
        }
        needsDisplay = true
    }

    override func mouseDragged(with e: NSEvent) {
        guard let s = dragStart else { return }
        let p = toImage(e)
        let shift = e.modifierFlags.contains(.shift)
        switch tool {
        case .select:
            guard let id = selectedID, let origin = moveOrigin,
                  let idx = origin.items.firstIndex(where: { $0.id == id }) else { return }
            var st = origin
            st.items[idx] = origin.items[idx].translated(dx: p.x - s.x, dy: p.y - s.y)
            moved = true
            doc.setLive(st)
        case .pen, .highlighter:
            if shift {
                let ang = (atan2(p.y - s.y, p.x - s.x) / (.pi / 12)).rounded() * (.pi / 12)
                let l = dist(s, p)
                draft?.shape = .freehand([s, CGPoint(x: s.x + cos(ang) * l, y: s.y + sin(ang) * l)])
            } else if case .freehand(var pts)? = draft?.shape {
                if pts.count == 2, dragShiftActive { pts = [s] }
                pts.append(p)
                draft?.shape = .freehand(pts)
            }
            dragShiftActive = shift
        case .line, .arrow:
            var q = p
            if shift {
                let ang = (atan2(p.y - s.y, p.x - s.x) / (.pi / 12)).rounded() * (.pi / 12)
                let l = dist(s, p)
                q = CGPoint(x: s.x + cos(ang) * l, y: s.y + sin(ang) * l)
            }
            draft = makeItem(tool == .line ? .line(s, q) : .arrow(s, q))
        case .rect, .ellipse, .mosaic, .crop:
            var q = p
            if shift {
                let side = max(abs(p.x - s.x), abs(p.y - s.y))
                q = CGPoint(x: s.x + (p.x >= s.x ? side : -side), y: s.y + (p.y >= s.y ? side : -side))
            }
            let r = CGRect(x: min(s.x, q.x), y: min(s.y, q.y), width: abs(q.x - s.x), height: abs(q.y - s.y))
            switch tool {
            case .rect: draft = makeItem(.rect(r))
            case .ellipse: draft = makeItem(.ellipse(r))
            case .mosaic: draft = makeItem(.mosaic(r))
            default: cropRect = r
            }
        default:
            break
        }
        needsDisplay = true
    }

    override func mouseUp(with e: NSEvent) {
        defer {
            draft = nil
            dragStart = nil
            needsDisplay = true
        }
        switch tool {
        case .select:
            if moved, let o = moveOrigin { doc.pushUndo(o) }
            moveOrigin = nil
        case .pen, .highlighter:
            guard let item = draft, case .freehand(let pts) = item.shape else { return }
            var st = doc.state
            st.items.append(item)
            doc.commit(st)
            // Separate undo step: ⌘Z after a snap brings back exactly what was drawn.
            if smart, let snapped = ShapeRecognizer.recognize(pts, unit: doc.unit, allowShapes: tool == .pen) {
                var st2 = doc.state
                st2.items[st2.items.count - 1].shape = snapped
                doc.commit(st2)
            }
        case .line, .arrow, .rect, .ellipse, .mosaic:
            guard let item = draft, item.bounds.width + item.bounds.height > 4 * doc.unit else { return }
            var st = doc.state
            st.items.append(item)
            doc.commit(st)
        case .crop:
            applyCrop()
        default:
            break
        }
    }

    private func applyCrop() {
        defer { cropRect = nil }
        guard let r = cropRect?.standardized.intersection(CGRect(origin: .zero, size: imageSize)).integral,
              r.width >= 8, r.height >= 8, let cropped = doc.state.image.cropping(to: r) else { return }
        let items = doc.state.items.map { $0.translated(dx: -r.minX, dy: -r.minY) }
        doc.commit(EditorState(image: cropped, items: items))
    }

    // MARK: text

    private func beginText(at p: CGPoint, editing: Item? = nil) {
        let m = metrics
        var initial = ""
        if let it = editing, case .text(let o, let str, let size) = it.shape {
            textOrigin = o
            textSizePx = size
            textColor = it.color
            editingID = it.id
            initial = str
            selectedID = nil
        } else {
            textOrigin = p
            textSizePx = textSize
            textColor = color
            editingID = nil
        }
        let fontPx = textSizePx * m.s
        let tf = NSTextField(frame: NSRect(x: m.origin.x + textOrigin.x * m.s - 2, y: m.origin.y + textOrigin.y * m.s - 1,
                                           width: 140, height: fontPx * 1.35 + 4))
        tf.isBordered = false
        tf.drawsBackground = false
        tf.focusRingType = .none
        tf.font = textFont(fontPx)
        tf.textColor = textColor
        tf.delegate = self
        tf.usesSingleLineMode = false
        tf.maximumNumberOfLines = 0
        tf.lineBreakMode = .byClipping
        tf.cell?.isScrollable = false
        tf.stringValue = initial
        addSubview(tf)
        textField = tf
        resizeTextField()
        window?.makeFirstResponder(tf)
        let end = (initial as NSString).length
        (tf.currentEditor() as? NSTextView)?.setSelectedRange(NSRange(location: end, length: 0))
        needsDisplay = true
    }

    private func resizeTextField() {
        guard let tf = textField, let font = tf.font else { return }
        let sz = (tf.stringValue as NSString).size(withAttributes: [.font: font])
        tf.frame.size = NSSize(width: max(140, sz.width + 28), height: max(font.pointSize * 1.35, sz.height) + 4)
    }

    func controlTextDidChange(_ obj: Notification) { resizeTextField() }

    /// Enter commits; ⌥/⌘/⇧ + Enter starts a new line.
    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        guard commandSelector == #selector(NSResponder.insertNewline(_:)) else { return false }
        let mods = NSApp.currentEvent?.modifierFlags ?? []
        if !mods.intersection([.option, .command, .shift]).isEmpty {
            textView.insertNewlineIgnoringFieldEditor(nil)
            return true
        }
        return false
    }

    func controlTextDidEndEditing(_ obj: Notification) { endText() }

    private func endText() {
        guard let tf = textField else { return }
        textField = nil
        tf.delegate = nil
        let s = tf.stringValue
        tf.isHidden = true
        DispatchQueue.main.async { [weak self] in
            tf.removeFromSuperview()
            self?.window?.makeFirstResponder(self)
        }
        let id = editingID
        editingID = nil
        var st = doc.state
        if let id = id, let idx = st.items.firstIndex(where: { $0.id == id }) {
            if s.isEmpty {
                st.items.remove(at: idx)
            } else if case .text(let o, let old, let size) = st.items[idx].shape, old != s {
                st.items[idx].shape = .text(origin: o, string: s, size: size)
            } else {
                needsDisplay = true
                return
            }
            doc.commit(st)
        } else if !s.isEmpty {
            st.items.append(Item(shape: .text(origin: textOrigin, string: s, size: textSizePx), color: textColor, width: lineWidth))
            doc.commit(st)
        }
        needsDisplay = true
    }

    // MARK: keys & menu actions

    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 51, 117:
            if let id = selectedID {
                var st = doc.state
                st.items.removeAll { $0.id == id }
                selectedID = nil
                doc.commit(st)
            }
        case 53:
            onClose?()
        default:
            super.keyDown(with: event)
        }
    }

    @objc func undo(_ sender: Any?) { endText(); selectedID = nil; doc.undo() }
    @objc func redo(_ sender: Any?) { selectedID = nil; doc.redo() }
    @objc func copy(_ sender: Any?) { endText(); onCopy?() }
    @objc func saveDocument(_ sender: Any?) { endText(); onSave?() }

    func exportImage() -> CGImage? {
        endText()
        return Renderer.export(doc.state, unit: doc.unit)
    }
}
