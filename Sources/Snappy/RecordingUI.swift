import AVFoundation
import AVKit
import AppKit
import UniformTypeIdentifiers

/// Icon button that flips between two SF Symbols (e.g. mic / muted mic).
final class ToggleIconButton: NSButton {
    private let onSymbol: String
    private let offSymbol: String
    var isOn: Bool { didSet { refresh() } }
    var onToggle: ((Bool) -> Void)?

    init(on: String, off: String, tip: String, isOn: Bool) {
        onSymbol = on
        offSymbol = off
        self.isOn = isOn
        super.init(frame: .zero)
        bezelStyle = .texturedRounded
        imagePosition = .imageOnly
        toolTip = tip
        target = self
        action = #selector(clicked)
        refresh()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func refresh() {
        image = NSImage(systemSymbolName: isOn ? onSymbol : offSymbol, accessibilityDescription: toolTip)
        contentTintColor = isOn ? .controlAccentColor : .systemRed
    }

    @objc private func clicked() {
        isOn.toggle()
        onToggle?(isOn)
    }
}

/// Small floating control bar shown while recording. It is excluded from the recording itself.
final class RecordingPanel {
    private let panel: NSPanel
    private let timeLabel = NSTextField(labelWithString: "00:00")
    private var timer: Timer?
    private let started = Date()

    init(screen: NSScreen, recorder: ScreenRecorder, onStop: @escaping () -> Void) {
        let mic = ToggleIconButton(on: "mic.fill", off: "mic.slash.fill", tip: tr("rec.mic"), isOn: Settings.shared.micOn)
        mic.onToggle = { on in Settings.shared.micOn = on; recorder.setMic(on) }
        let sys = ToggleIconButton(on: "speaker.wave.2.fill", off: "speaker.slash.fill", tip: tr("rec.sys"), isOn: Settings.shared.systemAudioOn)
        sys.onToggle = { on in Settings.shared.systemAudioOn = on; recorder.setSystem(on) }

        let dot = NSTextField(labelWithString: "●")
        dot.textColor = .systemRed
        timeLabel.font = .monospacedDigitSystemFont(ofSize: 14, weight: .medium)
        let stop = NSButton(title: tr("rec.stop"), target: nil, action: nil)
        stop.bezelStyle = .rounded
        stop.bezelColor = .systemRed
        stop.image = NSImage(systemSymbolName: "stop.fill", accessibilityDescription: nil)
        stop.imagePosition = .imageLeading
        let handler = StopHandler(onStop)
        stop.target = handler
        stop.action = #selector(StopHandler.fire)
        objc_setAssociatedObject(stop, "h", handler, .OBJC_ASSOCIATION_RETAIN)

        let hint = NSTextField(labelWithString: String(format: tr("rec.hint"), Settings.shared.hotKeyLabel))
        hint.font = .systemFont(ofSize: 11)
        hint.textColor = .secondaryLabelColor

        let row = NSStackView(views: [dot, timeLabel, mic, sys, stop])
        row.spacing = 10
        row.alignment = .centerY
        let col = NSStackView(views: [row, hint])
        col.orientation = .vertical
        col.spacing = 6
        col.edgeInsets = NSEdgeInsets(top: 10, left: 14, bottom: 10, right: 14)

        let box = NSVisualEffectView()
        box.material = .hudWindow
        box.state = .active
        box.wantsLayer = true
        box.layer?.cornerRadius = 14
        box.layer?.masksToBounds = true
        col.translatesAutoresizingMaskIntoConstraints = false
        box.addSubview(col)
        NSLayoutConstraint.activate([
            col.leadingAnchor.constraint(equalTo: box.leadingAnchor), col.trailingAnchor.constraint(equalTo: box.trailingAnchor),
            col.topAnchor.constraint(equalTo: box.topAnchor), col.bottomAnchor.constraint(equalTo: box.bottomAnchor),
        ])
        let size = box.fittingSize
        let vis = screen.visibleFrame
        let frame = NSRect(x: vis.midX - size.width / 2, y: vis.maxY - size.height - 14, width: size.width, height: size.height)
        panel = NSPanel(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.isMovableByWindowBackground = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.contentView = box
    }

    func show() {
        panel.orderFrontRegardless()
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            let s = Int(Date().timeIntervalSince(self.started))
            self.timeLabel.stringValue = String(format: "%02d:%02d", s / 60, s % 60)
        }
    }

    func close() {
        timer?.invalidate()
        panel.orderOut(nil)
    }
}

private final class StopHandler: NSObject {
    let block: () -> Void
    init(_ b: @escaping () -> Void) { block = b }
    @objc func fire() { block() }
}

/// Window shown after a recording: preview, reveal in Finder, copy the file, export a GIF.
final class VideoWindowController: NSWindowController, NSWindowDelegate {
    private let url: URL
    private let player: AVPlayer
    private let status = NSTextField(labelWithString: "")
    private let progress = NSProgressIndicator()
    private var gifButton: NSButton!
    var onClose: ((VideoWindowController) -> Void)?

    init(url: URL) {
        self.url = url
        player = AVPlayer(url: url)
        let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 880, height: 580), styleMask: [.titled, .closable, .miniaturizable, .resizable],
                         backing: .buffered, defer: false)
        w.title = tr("rec.window")
        w.minSize = NSSize(width: 560, height: 360)
        w.isReleasedWhenClosed = false
        super.init(window: w)
        w.delegate = self

        let view = AVPlayerView()
        view.player = player
        view.controlsStyle = .inline

        let reveal = NSButton(title: tr("rec.reveal"), target: self, action: #selector(revealInFinder))
        let copy = NSButton(title: tr("rec.copyfile"), target: self, action: #selector(copyFile))
        gifButton = NSButton(title: tr("rec.gif"), target: self, action: #selector(saveGIF))
        [reveal, copy, gifButton].forEach { $0.bezelStyle = .rounded }
        progress.style = .bar
        progress.isIndeterminate = false
        progress.minValue = 0
        progress.maxValue = 1
        progress.isHidden = true
        progress.widthAnchor.constraint(equalToConstant: 140).isActive = true
        status.textColor = .secondaryLabelColor
        status.font = .systemFont(ofSize: 11)
        let spacer = NSView()
        spacer.setContentHuggingPriority(.init(1), for: .horizontal)
        let bar = NSStackView(views: [reveal, copy, gifButton, progress, status, spacer])
        bar.spacing = 8
        bar.edgeInsets = NSEdgeInsets(top: 8, left: 12, bottom: 8, right: 12)

        let content = NSView()
        w.contentView = content
        view.translatesAutoresizingMaskIntoConstraints = false
        bar.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(view)
        content.addSubview(bar)
        NSLayoutConstraint.activate([
            view.topAnchor.constraint(equalTo: content.topAnchor), view.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            view.trailingAnchor.constraint(equalTo: content.trailingAnchor), view.bottomAnchor.constraint(equalTo: bar.topAnchor),
            bar.leadingAnchor.constraint(equalTo: content.leadingAnchor), bar.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            bar.bottomAnchor.constraint(equalTo: content.bottomAnchor),
        ])
        w.center()
    }

    required init?(coder: NSCoder) { fatalError() }

    func show() {
        NSApp.activate(ignoringOtherApps: true)
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        player.pause()
        onClose?(self)
    }

    @objc private func revealInFinder() { NSWorkspace.shared.activateFileViewerSelecting([url]) }

    @objc private func copyFile() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects([url as NSURL])
        status.stringValue = tr("rec.copied")
    }

    @objc private func saveGIF() {
        guard let window = window else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.gif]
        panel.directoryURL = url.deletingLastPathComponent()
        panel.nameFieldStringValue = url.deletingPathExtension().lastPathComponent + ".gif"
        panel.beginSheetModal(for: window) { [weak self] resp in
            guard resp == .OK, let dest = panel.url, let self = self else { return }
            self.gifButton.isEnabled = false
            self.progress.doubleValue = 0
            self.progress.isHidden = false
            self.status.stringValue = tr("rec.gif.working")
            let src = self.url
            Task {
                do {
                    try await GIFExporter.export(from: src, to: dest) { p in
                        DispatchQueue.main.async { self.progress.doubleValue = p }
                    }
                    await MainActor.run {
                        self.status.stringValue = tr("rec.gif.done")
                        NSWorkspace.shared.activateFileViewerSelecting([dest])
                    }
                } catch {
                    await MainActor.run { self.status.stringValue = error.localizedDescription }
                }
                await MainActor.run {
                    self.gifButton.isEnabled = true
                    self.progress.isHidden = true
                }
            }
        }
    }
}

enum GIFExporter {
    static func export(from url: URL, to dest: URL, progress: @escaping (Double) -> Void) async throws {
        let asset = AVURLAsset(url: url)
        let duration = try await asset.load(.duration).seconds
        let fps = min(10.0, 600 / max(duration, 1))
        let n = max(1, Int(duration * fps))
        let gen = AVAssetImageGenerator(asset: asset)
        gen.appliesPreferredTrackTransform = true
        gen.maximumSize = CGSize(width: 800, height: 800)
        gen.requestedTimeToleranceBefore = CMTime(value: 1, timescale: 20)
        gen.requestedTimeToleranceAfter = CMTime(value: 1, timescale: 20)
        guard let dst = CGImageDestinationCreateWithURL(dest as CFURL, UTType.gif.identifier as CFString, n, nil) else {
            throw NSError(domain: "BetterScreenshot", code: 3, userInfo: [NSLocalizedDescriptionKey: "Cannot create GIF"])
        }
        CGImageDestinationSetProperties(dst, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary)
        for i in 0..<n {
            let t = CMTime(seconds: Double(i) / fps, preferredTimescale: 600)
            let (img, _) = try await gen.image(at: t)
            CGImageDestinationAddImage(dst, img, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: 1 / fps]] as CFDictionary)
            progress(Double(i + 1) / Double(n))
        }
        guard CGImageDestinationFinalize(dst) else {
            throw NSError(domain: "BetterScreenshot", code: 4, userInfo: [NSLocalizedDescriptionKey: "GIF write failed"])
        }
    }
}
