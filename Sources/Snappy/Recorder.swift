import AVFoundation
import ScreenCaptureKit

/// Mixes system audio and microphone into one 48 kHz stereo timeline aligned to the video clock.
final class AudioMixer {
    static let rate: Double = 48000
    let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: rate, channels: 2, interleaved: true)!
    private let start: CMTime
    private var samples: [Float] = []   // interleaved L R
    private var base = 0                // frame index of samples[0]
    private var maxEnd = 0
    private var cursors: [Bool: Int] = [:]
    private var converters: [Bool: AVAudioConverter] = [:]

    init(start: CMTime) { self.start = start }

    func add(_ input: AVAudioPCMBuffer, pts: CMTime, system: Bool, enabled: Bool) {
        let conv: AVAudioConverter
        if let c = converters[system], c.inputFormat == input.format {
            conv = c
        } else if let c = AVAudioConverter(from: input.format, to: format) {
            converters[system] = c
            conv = c
        } else {
            return
        }
        let cap = AVAudioFrameCount(Double(input.frameLength) * Self.rate / input.format.sampleRate) + 256
        guard let out = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: cap) else { return }
        var given = false
        var err: NSError?
        conv.convert(to: out, error: &err) { _, status in
            if given { status.pointee = .noDataNow; return nil }
            given = true
            status.pointee = .haveData
            return input
        }
        let frames = Int(out.frameLength)
        guard err == nil, frames > 0, let data = out.floatChannelData?[0] else { return }

        // Contiguous buffers are chained; a jump of more than 50 ms re-syncs to the buffer's timestamp.
        let ptsIdx = Int(((pts - start).seconds * Self.rate).rounded())
        var idx = ptsIdx
        if let c = cursors[system], abs(ptsIdx - c) < 2400 { idx = c }
        cursors[system] = idx + frames
        maxEnd = max(maxEnd, idx + frames)
        guard enabled else { return }

        var from = 0
        if idx < base { from = base - idx }
        if idx < 0 { from = max(from, -idx) }
        guard from < frames else { return }
        let begin = idx + from
        let need = (idx + frames - base) * 2
        if samples.count < need { samples.append(contentsOf: [Float](repeating: 0, count: need - samples.count)) }
        for f in from..<frames {
            let o = (begin + (f - from) - base) * 2
            samples[o] += data[f * 2]
            samples[o + 1] += data[f * 2 + 1]
        }
    }

    /// Returns the next finished chunk (everything older than 300 ms, or everything when `final`).
    func flush(final: Bool) -> CMSampleBuffer? {
        let target = final ? maxEnd : maxEnd - 14400
        let count = min(target - base, samples.count / 2)
        guard count >= (final ? 1 : 4800) else { return nil }
        guard let out = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(count)),
              let dst = out.floatChannelData?[0] else { return nil }
        out.frameLength = AVAudioFrameCount(count)
        for i in 0..<(count * 2) { dst[i] = max(-1, min(1, samples[i])) }
        samples.removeFirst(count * 2)
        let pts = CMTimeAdd(start, CMTime(value: CMTimeValue(base), timescale: CMTimeScale(Self.rate)))
        base += count
        return Self.sampleBuffer(from: out, pts: pts)
    }

    private static func sampleBuffer(from buf: AVAudioPCMBuffer, pts: CMTime) -> CMSampleBuffer? {
        var fd: CMAudioFormatDescription?
        guard CMAudioFormatDescriptionCreate(allocator: nil, asbd: buf.format.streamDescription, layoutSize: 0, layout: nil,
                                             magicCookieSize: 0, magicCookie: nil, extensions: nil, formatDescriptionOut: &fd) == noErr else { return nil }
        var timing = CMSampleTimingInfo(duration: CMTime(value: 1, timescale: CMTimeScale(rate)), presentationTimeStamp: pts, decodeTimeStamp: .invalid)
        var sb: CMSampleBuffer?
        guard CMSampleBufferCreate(allocator: nil, dataBuffer: nil, dataReady: false, makeDataReadyCallback: nil, refcon: nil,
                                   formatDescription: fd, sampleCount: CMItemCount(buf.frameLength), sampleTimingEntryCount: 1,
                                   sampleTimingArray: &timing, sampleSizeEntryCount: 0, sampleSizeArray: nil, sampleBufferOut: &sb) == noErr,
              let s = sb else { return nil }
        guard CMSampleBufferSetDataBufferFromAudioBufferList(s, blockBufferAllocator: kCFAllocatorDefault, blockBufferMemoryAllocator: kCFAllocatorDefault,
                                                             flags: 0, bufferList: buf.audioBufferList) == noErr else { return nil }
        return s
    }
}

final class ScreenRecorder: NSObject, SCStreamOutput, SCStreamDelegate {
    private var stream: SCStream?
    private var config = SCStreamConfiguration()
    private var writer: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var audioInput: AVAssetWriterInput?
    private var mixer: AudioMixer?
    private let queue = DispatchQueue(label: "bettershot.recorder")
    private let lock = NSLock()
    private var micOn = false
    private var systemOn = false
    private var startPTS: CMTime?
    private var lastVideoPTS: CMTime = .zero
    private(set) var startDate = Date()
    private(set) var url: URL?
    var onError: ((Error) -> Void)?

    func start(screen: NSScreen, rect: CGRect, url: URL, mic: Bool, system: Bool) async throws {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        guard let num = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID,
              let display = content.displays.first(where: { $0.displayID == num }) else {
            throw NSError(domain: "BetterScreenshot", code: 1, userInfo: [NSLocalizedDescriptionKey: "Display not found"])
        }
        let own = content.applications.filter { $0.processID == getpid() }
        let filter = SCContentFilter(display: display, excludingApplications: own, exceptingWindows: [])
        let scale = screen.backingScaleFactor
        let w = max(2, Int(rect.width * scale) & ~1), h = max(2, Int(rect.height * scale) & ~1)

        micOn = mic
        systemOn = system
        let cfg = SCStreamConfiguration()
        cfg.width = w
        cfg.height = h
        cfg.sourceRect = rect
        cfg.minimumFrameInterval = CMTime(value: 1, timescale: 30)
        cfg.queueDepth = 6
        cfg.showsCursor = true
        cfg.capturesAudio = system
        cfg.excludesCurrentProcessAudio = true
        cfg.sampleRate = 48000
        cfg.channelCount = 2
        cfg.captureMicrophone = mic
        config = cfg

        try? FileManager.default.removeItem(at: url)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let wr = try AVAssetWriter(outputURL: url, fileType: .mp4)
        let vi = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: w, AVVideoHeightKey: h,
            AVVideoCompressionPropertiesKey: [AVVideoAverageBitRateKey: max(3_000_000, w * h * 3),
                                              AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
                                              AVVideoExpectedSourceFrameRateKey: 30],
        ])
        vi.expectsMediaDataInRealTime = true
        let ai = AVAssetWriterInput(mediaType: .audio, outputSettings: [
            AVFormatIDKey: kAudioFormatMPEG4AAC, AVSampleRateKey: 48000, AVNumberOfChannelsKey: 2, AVEncoderBitRateKey: 128_000,
        ])
        ai.expectsMediaDataInRealTime = true
        wr.add(vi)
        wr.add(ai)
        guard wr.startWriting() else { throw wr.error ?? NSError(domain: "BetterScreenshot", code: 2) }
        writer = wr
        videoInput = vi
        audioInput = ai
        startPTS = nil
        mixer = nil
        self.url = url

        let s = SCStream(filter: filter, configuration: cfg, delegate: self)
        try s.addStreamOutput(self, type: .screen, sampleHandlerQueue: queue)
        try s.addStreamOutput(self, type: .audio, sampleHandlerQueue: queue)
        try s.addStreamOutput(self, type: .microphone, sampleHandlerQueue: queue)
        try await s.startCapture()
        stream = s
        startDate = Date()
    }

    func setMic(_ on: Bool) {
        lock.lock(); micOn = on; lock.unlock()
        config.captureMicrophone = on
        update()
    }

    func setSystem(_ on: Bool) {
        lock.lock(); systemOn = on; lock.unlock()
        config.capturesAudio = on
        update()
    }

    private func update() {
        guard let s = stream else { return }
        let cfg = config
        Task { try? await s.updateConfiguration(cfg) }
    }

    func stop() async -> URL? {
        guard let s = stream else { return nil }
        stream = nil
        try? await s.stopCapture()
        let ok: Bool = await withCheckedContinuation { cont in
            queue.async {
                guard let wr = self.writer, self.startPTS != nil else {
                    self.writer?.cancelWriting()
                    cont.resume(returning: false)
                    return
                }
                if let sb = self.mixer?.flush(final: true), self.audioInput?.isReadyForMoreMediaData == true {
                    self.audioInput?.append(sb)
                }
                self.videoInput?.markAsFinished()
                self.audioInput?.markAsFinished()
                let now = CMClockGetTime(CMClockGetHostTimeClock())
                wr.endSession(atSourceTime: CMTimeMaximum(now, self.lastVideoPTS))
                wr.finishWriting { cont.resume(returning: wr.status == .completed) }
            }
        }
        return ok ? url : nil
    }

    // MARK: SCStreamOutput

    func stream(_ stream: SCStream, didOutputSampleBuffer sb: CMSampleBuffer, of type: SCStreamOutputType) {
        guard sb.isValid, writer?.status == .writing else { return }
        switch type {
        case .screen: handleVideo(sb)
        case .audio: handleAudio(sb, system: true)
        case .microphone: handleAudio(sb, system: false)
        @unknown default: break
        }
    }

    func stream(_ stream: SCStream, didStopWithError error: Error) {
        DispatchQueue.main.async { self.onError?(error) }
    }

    private func handleVideo(_ sb: CMSampleBuffer) {
        guard let atts = CMSampleBufferGetSampleAttachmentsArray(sb, createIfNecessary: false) as? [[SCStreamFrameInfo: Any]],
              let raw = atts.first?[.status] as? Int, SCFrameStatus(rawValue: raw) == .complete,
              CMSampleBufferGetImageBuffer(sb) != nil, let vi = videoInput else { return }
        let pts = CMSampleBufferGetPresentationTimeStamp(sb)
        if startPTS == nil {
            startPTS = pts
            writer?.startSession(atSourceTime: pts)
            mixer = AudioMixer(start: pts)
        }
        if vi.isReadyForMoreMediaData, vi.append(sb) { lastVideoPTS = pts }
    }

    private func handleAudio(_ sb: CMSampleBuffer, system: Bool) {
        guard let mixer = mixer, let ai = audioInput, let pcm = Self.pcmBuffer(from: sb) else { return }
        lock.lock()
        let enabled = system ? systemOn : micOn
        lock.unlock()
        mixer.add(pcm, pts: CMSampleBufferGetPresentationTimeStamp(sb), system: system, enabled: enabled)
        if let out = mixer.flush(final: false), ai.isReadyForMoreMediaData { ai.append(out) }
    }

    private static func pcmBuffer(from sb: CMSampleBuffer) -> AVAudioPCMBuffer? {
        guard let fd = CMSampleBufferGetFormatDescription(sb),
              let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(fd) else { return nil }
        var a = asbd.pointee
        guard let fmt = AVAudioFormat(streamDescription: &a) else { return nil }
        let n = AVAudioFrameCount(CMSampleBufferGetNumSamples(sb))
        guard n > 0, let buf = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: n) else { return nil }
        buf.frameLength = n
        let st = CMSampleBufferCopyPCMDataIntoAudioBufferList(sb, at: 0, frameCount: Int32(n), into: buf.mutableAudioBufferList)
        return st == noErr ? buf : nil
    }
}
