import AppKit
import Vision

/// On-device text recognition (Vision) plus QR / bar code decoding.
enum TextRecognizer {
    /// Recognized lines in reading order, followed by the payloads of any QR / bar codes found.
    static func recognize(_ image: CGImage) async -> String {
        await withCheckedContinuation { cont in
            DispatchQueue.global(qos: .userInitiated).async {
                cont.resume(returning: run(image))
            }
        }
    }

    private struct Piece {
        let box: CGRect
        let string: String
    }

    private static func run(_ image: CGImage) -> String {
        let text = VNRecognizeTextRequest()
        text.recognitionLevel = .accurate
        text.usesLanguageCorrection = true
        text.automaticallyDetectsLanguage = true
        let codes = VNDetectBarcodesRequest()
        try? VNImageRequestHandler(cgImage: image, options: [:]).perform([text, codes])

        var parts: [String] = []
        let pieces = (text.results ?? []).compactMap { o -> Piece? in
            o.topCandidates(1).first.map { Piece(box: o.boundingBox, string: $0.string) }
        }
        let lines = joinLines(pieces)
        if !lines.isEmpty { parts.append(lines) }
        for c in codes.results ?? [] {
            if let p = c.payloadStringValue, !p.isEmpty, !parts.contains(p) { parts.append(p) }
        }
        return parts.joined(separator: "\n")
    }

    /// Vision boxes are normalized with a bottom-left origin: sort top to bottom, then merge pieces that share a line.
    private static func joinLines(_ pieces: [Piece]) -> String {
        var lines: [[Piece]] = []
        for p in pieces.sorted(by: { $0.box.midY > $1.box.midY }) {
            if let ref = lines.last?.first, abs(ref.box.midY - p.box.midY) < min(ref.box.height, p.box.height) * 0.5 {
                lines[lines.count - 1].append(p)
            } else {
                lines.append([p])
            }
        }
        return lines.map { $0.sorted { $0.box.minX < $1.box.minX }.map(\.string).joined(separator: " ") }
            .joined(separator: "\n")
    }
}
