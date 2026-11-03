import CoreGraphics

/// Turns a hand-drawn stroke into a clean line / arrow / rectangle / ellipse when it looks like one.
enum ShapeRecognizer {
    static func recognize(_ raw: [CGPoint], unit: CGFloat, allowShapes: Bool) -> Shape? {
        var pts: [CGPoint] = []
        for p in raw where pts.last.map({ dist($0, p) > 0.5 }) ?? true { pts.append(p) }
        guard pts.count >= 4 else { return nil }
        let pathLen = zip(pts, pts.dropFirst()).reduce(0) { $0 + dist($1.0, $1.1) }
        guard pathLen > 24 * unit else { return nil }
        let first = pts[0], last = pts[pts.count - 1]
        let chord = dist(first, last)

        if chord / pathLen > 0.9 {
            let dev = pts.map { distToSegment($0, first, last) }.max() ?? 0
            if dev < 0.08 * chord { return .line(first, last) }
        }
        guard allowShapes else { return nil }

        if chord < 0.22 * pathLen { return closedShape(pts, unit: unit) }
        return arrow(pts, pathLen: pathLen)
    }

    private static func closedShape(_ pts: [CGPoint], unit: CGFloat) -> Shape? {
        let box = boundingBox(pts)
        guard min(box.width, box.height) > 16 * unit else { return nil }
        let rs = resample(pts, n: 64)
        let a = box.width / 2, b = box.height / 2
        var n2: [CGFloat] = [], nInf: [CGFloat] = []
        for p in rs {
            let u = (p.x - box.midX) / a, v = (p.y - box.midY) / b
            n2.append(hypot(u, v))
            nInf.append(max(abs(u), abs(v)))
        }
        let cv2 = coefficientOfVariation(n2), cvInf = coefficientOfVariation(nInf)
        if cvInf < cv2 {
            return cvInf < 0.1 ? .rect(box) : nil
        }
        return cv2 < 0.12 ? .ellipse(box) : nil
    }

    private static func arrow(_ pts: [CGPoint], pathLen: CGFloat) -> Shape? {
        let box = boundingBox(pts)
        let poly = rdp(pts, epsilon: 0.035 * hypot(box.width, box.height))
        guard poly.count >= 3, poly.count <= 7 else { return nil }
        var longest = 0
        var shaft: CGFloat = 0
        for i in 0..<(poly.count - 1) {
            let l = dist(poly[i], poly[i + 1])
            if l > shaft { shaft = l; longest = i }
        }
        guard shaft >= 0.4 * pathLen else { return nil }

        let tail: CGPoint, tip: CGPoint, head: [CGPoint]
        if longest == 0 {
            tail = poly[0]; tip = poly[1]; head = Array(poly[2...])
        } else if longest == poly.count - 2 {
            tip = poly[longest]; tail = poly[longest + 1]; head = Array(poly[..<longest])
        } else {
            return nil
        }
        let back = CGPoint(x: tail.x - tip.x, y: tail.y - tip.y)
        let backAngle = atan2(back.y, back.x)
        var barbs = 0
        for h in head {
            let d = dist(h, tip)
            if d > 0.65 * shaft { return nil }
            if d < 0.1 * shaft { continue }
            var diff = abs(atan2(h.y - tip.y, h.x - tip.x) - backAngle)
            if diff > .pi { diff = 2 * .pi - diff }
            let deg = diff * 180 / .pi
            guard deg > 8, deg < 75 else { return nil }
            barbs += 1
        }
        return barbs > 0 ? .arrow(tail, tip) : nil
    }

    private static func coefficientOfVariation(_ v: [CGFloat]) -> CGFloat {
        let mean = v.reduce(0, +) / CGFloat(v.count)
        guard mean > 0 else { return 1 }
        let variance = v.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / CGFloat(v.count)
        return sqrt(variance) / mean
    }

    private static func resample(_ pts: [CGPoint], n: Int) -> [CGPoint] {
        let total = zip(pts, pts.dropFirst()).reduce(0) { $0 + dist($1.0, $1.1) }
        let step = total / CGFloat(n)
        var out = [pts[0]]
        var acc: CGFloat = 0
        var prev = pts[0]
        for p in pts.dropFirst() {
            var seg = dist(prev, p)
            while acc + seg >= step && seg > 0 {
                let t = (step - acc) / seg
                let q = CGPoint(x: prev.x + (p.x - prev.x) * t, y: prev.y + (p.y - prev.y) * t)
                out.append(q)
                prev = q
                seg = dist(prev, p)
                acc = 0
            }
            acc += seg
            prev = p
        }
        return out
    }

    private static func rdp(_ pts: [CGPoint], epsilon: CGFloat) -> [CGPoint] {
        guard pts.count > 2 else { return pts }
        var maxD: CGFloat = 0, idx = 0
        for i in 1..<(pts.count - 1) {
            let d = distToSegment(pts[i], pts[0], pts[pts.count - 1])
            if d > maxD { maxD = d; idx = i }
        }
        if maxD > epsilon {
            let l = rdp(Array(pts[...idx]), epsilon: epsilon)
            let r = rdp(Array(pts[idx...]), epsilon: epsilon)
            return Array(l.dropLast()) + r
        }
        return [pts[0], pts[pts.count - 1]]
    }
}
