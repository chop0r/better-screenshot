// Generates Resources/AppIcon.icns: swift tools/make-icon.swift
import AppKit

func render(_ px: Int) -> Data {
    let s = CGFloat(px)
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8, samplesPerPixel: 4,
                               hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let ctx = NSGraphicsContext.current!.cgContext
    let body = CGRect(x: s * 0.098, y: s * 0.098, width: s * 0.804, height: s * 0.804)
    let path = NSBezierPath(roundedRect: body, xRadius: s * 0.18, yRadius: s * 0.18)

    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -s * 0.012), blur: s * 0.03, color: NSColor.black.withAlphaComponent(0.35).cgColor)
    NSColor.black.setFill()
    path.fill()
    ctx.restoreGState()

    ctx.saveGState()
    path.addClip()
    NSGradient(colors: [NSColor(red: 0.30, green: 0.78, blue: 0.95, alpha: 1), NSColor(red: 0.18, green: 0.32, blue: 0.86, alpha: 1)])!
        .draw(in: body, angle: -60)
    ctx.restoreGState()

    // viewfinder corners
    NSColor.white.setStroke()
    let arm = body.width * 0.2, inset = body.width * 0.2
    let lw = s * 0.045
    let l = body.minX + inset, r = body.maxX - inset, b = body.minY + inset, t = body.maxY - inset
    let corners = NSBezierPath()
    corners.lineWidth = lw
    corners.lineCapStyle = .round
    corners.lineJoinStyle = .round
    for (x, y, dx, dy) in [(l, t, 1.0, -1.0), (r, t, -1.0, -1.0), (l, b, 1.0, 1.0), (r, b, -1.0, 1.0)] as [(CGFloat, CGFloat, CGFloat, CGFloat)] {
        corners.move(to: CGPoint(x: x + dx * arm, y: y))
        corners.line(to: CGPoint(x: x, y: y))
        corners.line(to: CGPoint(x: x, y: y + dy * arm))
    }
    corners.stroke()

    // red annotation arrow
    let a = CGPoint(x: body.midX - body.width * 0.17, y: body.midY - body.height * 0.15)
    let tip = CGPoint(x: body.midX + body.width * 0.17, y: body.midY + body.height * 0.15)
    let red = NSColor(red: 1.0, green: 0.25, blue: 0.3, alpha: 1)
    red.setStroke(); red.setFill()
    let dx = tip.x - a.x, dy = tip.y - a.y, len = hypot(dx, dy)
    let ux = dx / len, uy = dy / len
    let head = s * 0.13
    let shaft = NSBezierPath()
    shaft.lineWidth = s * 0.05
    shaft.lineCapStyle = .round
    shaft.move(to: a)
    shaft.line(to: CGPoint(x: tip.x - ux * head * 0.8, y: tip.y - uy * head * 0.8))
    shaft.stroke()
    let tri = NSBezierPath()
    tri.move(to: tip)
    for ang in [0.5, -0.5] as [CGFloat] {
        tri.line(to: CGPoint(x: tip.x - (ux * cos(ang) - uy * sin(ang)) * head, y: tip.y - (ux * sin(ang) + uy * cos(ang)) * head))
    }
    tri.close()
    tri.fill()

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let dir = "Resources/AppIcon.iconset"
try? FileManager.default.removeItem(atPath: dir)
try! FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
for base in [16, 32, 128, 256, 512] {
    try! render(base).write(to: URL(fileURLWithPath: "\(dir)/icon_\(base)x\(base).png"))
    try! render(base * 2).write(to: URL(fileURLWithPath: "\(dir)/icon_\(base)x\(base)@2x.png"))
}
