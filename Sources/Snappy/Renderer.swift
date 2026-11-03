import AppKit

/// Draws the base image and annotations into a top-left-origin (y down) CGContext in image pixel coordinates.
enum Renderer {
    static func draw(_ state: EditorState, extra: Item? = nil, in ctx: CGContext, unit: CGFloat) {
        let w = CGFloat(state.image.width), h = CGFloat(state.image.height)
        ctx.saveGState()
        ctx.translateBy(x: 0, y: h)
        ctx.scaleBy(x: 1, y: -1)
        ctx.interpolationQuality = .high
        ctx.draw(state.image, in: CGRect(x: 0, y: 0, width: w, height: h))
        ctx.restoreGState()
        for item in state.items { draw(item, base: state.image, in: ctx, unit: unit) }
        if let e = extra { draw(e, base: state.image, in: ctx, unit: unit) }
    }

    static func export(_ state: EditorState, unit: CGFloat) -> CGImage? {
        let w = state.image.width, h = state.image.height
        let space = state.image.colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB)!
        let info = CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        guard let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: space, bitmapInfo: info)
            ?? CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                         space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: info) else { return nil }
        ctx.translateBy(x: 0, y: CGFloat(h))
        ctx.scaleBy(x: 1, y: -1)
        draw(state, in: ctx, unit: unit)
        return ctx.makeImage()
    }

    static func draw(_ item: Item, base: CGImage, in ctx: CGContext, unit: CGFloat) {
        ctx.saveGState()
        defer { ctx.restoreGState() }
        ctx.setAlpha(item.opacity)
        ctx.setStrokeColor(item.color.cgColor)
        ctx.setFillColor(item.color.cgColor)
        ctx.setLineWidth(item.width)
        ctx.setLineCap(item.highlighter ? .butt : .round)
        ctx.setLineJoin(.round)

        switch item.shape {
        case .freehand(let pts):
            guard let f = pts.first else { return }
            if pts.count == 1 {
                ctx.fillEllipse(in: CGRect(x: f.x - item.width / 2, y: f.y - item.width / 2, width: item.width, height: item.width))
                return
            }
            let path = CGMutablePath()
            path.move(to: f)
            for i in 1..<pts.count {
                let mid = CGPoint(x: (pts[i - 1].x + pts[i].x) / 2, y: (pts[i - 1].y + pts[i].y) / 2)
                path.addQuadCurve(to: mid, control: pts[i - 1])
            }
            path.addLine(to: pts[pts.count - 1])
            ctx.addPath(path)
            ctx.strokePath()

        case .line(let a, let b):
            ctx.move(to: a)
            ctx.addLine(to: b)
            ctx.strokePath()

        case .arrow(let a, let b):
            let len = dist(a, b)
            guard len > 0 else { return }
            let d = CGPoint(x: (b.x - a.x) / len, y: (b.y - a.y) / len)
            let headLen = min(item.width * 4 + 6 * unit, len * 0.9)
            let base = CGPoint(x: b.x - d.x * headLen * 0.8, y: b.y - d.y * headLen * 0.8)
            ctx.move(to: a)
            ctx.addLine(to: base)
            ctx.strokePath()
            let ang: CGFloat = 0.5
            func rot(_ a: CGFloat) -> CGPoint {
                CGPoint(x: b.x - (d.x * cos(a) - d.y * sin(a)) * headLen, y: b.y - (d.x * sin(a) + d.y * cos(a)) * headLen)
            }
            ctx.move(to: b)
            ctx.addLine(to: rot(ang))
            ctx.addLine(to: rot(-ang))
            ctx.closePath()
            ctx.setLineWidth(max(1, item.width * 0.3))
            ctx.drawPath(using: .fillStroke)

        case .rect(let r):
            ctx.stroke(r.standardized)

        case .ellipse(let r):
            ctx.strokeEllipse(in: r.standardized)

        case .text(let o, let s, let size):
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: true)
            (s as NSString).draw(at: o, withAttributes: [.font: textFont(size), .foregroundColor: item.color])
            NSGraphicsContext.restoreGraphicsState()

        case .number(let c, let v, let size):
            let d = size * 1.7
            ctx.fillEllipse(in: CGRect(x: c.x - d / 2, y: c.y - d / 2, width: d, height: d))
            let str = "\(v)" as NSString
            let attrs: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: size, weight: .bold),
                                                        .foregroundColor: NSColor.white]
            let sz = str.size(withAttributes: attrs)
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: true)
            str.draw(at: CGPoint(x: c.x - sz.width / 2, y: c.y - sz.height / 2), withAttributes: attrs)
            NSGraphicsContext.restoreGraphicsState()

        case .mosaic(let r):
            let bounds = CGRect(x: 0, y: 0, width: base.width, height: base.height)
            let rect = r.standardized.intersection(bounds).integral
            guard rect.width >= 1, rect.height >= 1, let crop = base.cropping(to: rect) else { return }
            let block = max(item.width, 2)
            let sw = max(1, Int(ceil(rect.width / block))), sh = max(1, Int(ceil(rect.height / block)))
            guard let small = CGContext(data: nil, width: sw, height: sh, bitsPerComponent: 8, bytesPerRow: 0,
                                        space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return }
            small.interpolationQuality = .high
            small.draw(crop, in: CGRect(x: 0, y: 0, width: sw, height: sh))
            guard let tiny = small.makeImage() else { return }
            ctx.setAlpha(1)
            ctx.clip(to: rect)
            ctx.interpolationQuality = .none
            ctx.translateBy(x: rect.minX, y: rect.maxY)
            ctx.scaleBy(x: 1, y: -1)
            ctx.draw(tiny, in: CGRect(x: 0, y: 0, width: rect.width, height: rect.height))
        }
    }
}
