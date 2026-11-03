import AppKit
import UniformTypeIdentifiers

final class SwatchButton: NSButton {
    var swatchColor: NSColor = .red
    var isOn = false { didSet { needsDisplay = true } }

    override func draw(_ dirtyRect: NSRect) {
        let r = bounds.insetBy(dx: 3, dy: 3)
        swatchColor.setFill()
        NSBezierPath(ovalIn: r).fill()
        if swatchColor == .white {
            NSColor.separatorColor.setStroke()
            NSBezierPath(ovalIn: r).stroke()
        }
        if isOn {
            NSColor.controlAccentColor.setStroke()
            let ring = NSBezierPath(ovalIn: bounds.insetBy(dx: 1, dy: 1))
            ring.lineWidth = 2
            ring.stroke()
        }
    }
}

final class EditorController: NSWindowController, NSWindowDelegate {
    private let doc: EditorDocument
    private let canvas: CanvasView
    private var toolButtons: [NSButton] = []
    private var swatches: [SwatchButton] = []
    private let undoButton = NSButton()
    private let redoButton = NSButton()
    private let wellButton = NSColorWell(style: .minimal)
    var onClose: ((EditorController) -> Void)?

    private static let palette: [NSColor] = [.systemRed, .systemOrange, .systemYellow, .systemGreen, .systemBlue, .black, .white]

    init(image: CGImage, scale: CGFloat) {
        doc = EditorDocument(image: image, unit: scale)
        canvas = CanvasView(doc: doc)

        let vis = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1400, height: 900)
        let pw = CGFloat(image.width) / scale, ph = CGFloat(image.height) / scale
        let width = min(max(pw + 80, 960), vis.width * 0.92)
        let height = min(max(ph + 80 + 90, 560), vis.height * 0.92)
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: width, height: height),
                              styleMask: [.titled, .closable, .miniaturizable, .resizable],
                              backing: .buffered, defer: false)
        window.title = "Редактор скриншота"
        window.minSize = NSSize(width: 900, height: 480)
        window.isReleasedWhenClosed = false
        super.init(window: window)
        window.delegate = self
        buildUI(in: window)
        window.center()

        canvas.onCopy = { [weak self] in self?.copyAndClose() }
        canvas.onSave = { [weak self] in self?.save() }
        canvas.onClose = { [weak self] in self?.window?.close() }
        let prev = doc.onChange
        doc.onChange = { [weak self] in
            prev?()
            self?.updateButtons()
        }
        select(tool: .pen)
        updateButtons()
    }

    required init?(coder: NSCoder) { fatalError() }

    func show() {
        NSApp.activate(ignoringOtherApps: true)
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
        window?.makeFirstResponder(canvas)
    }

    func windowWillClose(_ notification: Notification) {
        onClose?(self)
    }

    // MARK: UI

    private func iconButton(_ symbol: String, tip: String, action: Selector) -> NSButton {
        let b = NSButton()
        if let img = NSImage(systemSymbolName: symbol, accessibilityDescription: tip) {
            b.image = img
            b.imagePosition = .imageOnly
        } else {
            b.title = String(tip.prefix(1))
        }
        b.bezelStyle = .texturedRounded
        b.toolTip = tip
        b.target = self
        b.action = action
        return b
    }

    private func buildUI(in window: NSWindow) {
        let content = NSView()
        window.contentView = content

        for t in Tool.allCases {
            let b = iconButton(t.symbol, tip: t.title, action: #selector(toolClicked(_:)))
            b.setButtonType(.pushOnPushOff)
            b.tag = t.rawValue
            toolButtons.append(b)
        }
        let tools = NSStackView(views: toolButtons)
        tools.spacing = 2

        configure(undoButton, symbol: "arrow.uturn.backward", tip: "Отменить (⌘Z)", action: #selector(undoClicked))
        configure(redoButton, symbol: "arrow.uturn.forward", tip: "Вернуть (⇧⌘Z)", action: #selector(redoClicked))
        let save = NSButton(title: "Сохранить…", target: self, action: #selector(saveClicked))
        save.bezelStyle = .rounded
        let copy = NSButton(title: "Копировать", target: self, action: #selector(copyClicked))
        copy.bezelStyle = .rounded
        copy.bezelColor = .controlAccentColor
        copy.toolTip = "Скопировать результат в буфер и закрыть (⌘C)"

        let spacer = NSView()
        spacer.setContentHuggingPriority(.init(1), for: .horizontal)
        let row1 = NSStackView(views: [tools, spacer, undoButton, redoButton, save, copy])
        row1.spacing = 8

        for (i, c) in Self.palette.enumerated() {
            let s = SwatchButton()
            s.isBordered = false
            s.title = ""
            s.swatchColor = c
            s.tag = i
            s.target = self
            s.action = #selector(swatchClicked(_:))
            s.widthAnchor.constraint(equalToConstant: 22).isActive = true
            s.heightAnchor.constraint(equalToConstant: 22).isActive = true
            swatches.append(s)
        }
        wellButton.color = .systemPink
        wellButton.target = self
        wellButton.action = #selector(wellChanged(_:))
        wellButton.widthAnchor.constraint(equalToConstant: 30).isActive = true
        wellButton.heightAnchor.constraint(equalToConstant: 22).isActive = true
        let sizes = NSSegmentedControl(labels: ["Тонко", "Средне", "Толсто"], trackingMode: .selectOne,
                                       target: self, action: #selector(sizeChanged(_:)))
        sizes.selectedSegment = 1
        let smart = NSButton(checkboxWithTitle: "Выпрямлять фигуры", target: self, action: #selector(smartChanged(_:)))
        smart.state = .on
        smart.toolTip = "Нарисованные от руки круг, прямоугольник, линия и стрелка станут ровными. ⌘Z вернёт как было."
        let hint = NSTextField(labelWithString: "Shift — ровные углы / квадрат")
        hint.textColor = .secondaryLabelColor
        hint.font = .systemFont(ofSize: 11)
        let row2 = NSStackView(views: swatches + [wellButton, sizes, smart, hint])
        row2.spacing = 8
        row2.setCustomSpacing(18, after: wellButton)
        row2.setCustomSpacing(18, after: sizes)

        let bar = NSStackView(views: [row1, row2])
        bar.orientation = .vertical
        bar.alignment = .leading
        bar.spacing = 8
        bar.edgeInsets = NSEdgeInsets(top: 10, left: 12, bottom: 10, right: 12)
        row1.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(bar)
        content.addSubview(canvas)
        bar.translatesAutoresizingMaskIntoConstraints = false
        canvas.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            bar.topAnchor.constraint(equalTo: content.topAnchor),
            bar.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            bar.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            row1.leadingAnchor.constraint(equalTo: bar.leadingAnchor, constant: 12),
            row1.trailingAnchor.constraint(equalTo: bar.trailingAnchor, constant: -12),
            canvas.topAnchor.constraint(equalTo: bar.bottomAnchor),
            canvas.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            canvas.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            canvas.bottomAnchor.constraint(equalTo: content.bottomAnchor),
        ])
        swatchClicked(swatches[0])
    }

    private func configure(_ b: NSButton, symbol: String, tip: String, action: Selector) {
        b.image = NSImage(systemSymbolName: symbol, accessibilityDescription: tip)
        b.imagePosition = .imageOnly
        b.bezelStyle = .texturedRounded
        b.toolTip = tip
        b.target = self
        b.action = action
    }

    private func updateButtons() {
        undoButton.isEnabled = doc.canUndo
        redoButton.isEnabled = doc.canRedo
    }

    private func select(tool: Tool) {
        canvas.tool = tool
        for b in toolButtons { b.state = b.tag == tool.rawValue ? .on : .off }
    }

    // MARK: actions

    @objc private func toolClicked(_ sender: NSButton) {
        select(tool: Tool(rawValue: sender.tag) ?? .pen)
    }

    @objc private func swatchClicked(_ sender: SwatchButton) {
        canvas.color = sender.swatchColor
        for s in swatches { s.isOn = s === sender }
    }

    @objc private func wellChanged(_ sender: NSColorWell) {
        canvas.color = sender.color
        for s in swatches { s.isOn = false }
    }

    @objc private func sizeChanged(_ sender: NSSegmentedControl) { canvas.sizeIndex = sender.selectedSegment }
    @objc private func smartChanged(_ sender: NSButton) { canvas.smart = sender.state == .on }
    @objc private func undoClicked() { canvas.undo(nil) }
    @objc private func redoClicked() { canvas.redo(nil) }
    @objc private func copyClicked() { copyAndClose() }
    @objc private func saveClicked() { save() }

    private func copyAndClose() {
        guard let img = canvas.exportImage() else { return }
        Clipboard.copy(img, scale: doc.unit)
        window?.close()
    }

    private func save() {
        guard let img = canvas.exportImage(), let window = window else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.directoryURL = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd 'at' HH.mm.ss"
        panel.nameFieldStringValue = "Screenshot \(f.string(from: Date())).png"
        panel.beginSheetModal(for: window) { [scale = doc.unit] resp in
            guard resp == .OK, let url = panel.url else { return }
            let rep = NSBitmapImageRep(cgImage: img)
            rep.size = NSSize(width: CGFloat(img.width) / scale, height: CGFloat(img.height) / scale)
            do {
                try rep.representation(using: .png, properties: [:])?.write(to: url)
            } catch {
                NSAlert(error: error).runModal()
            }
        }
    }
}
