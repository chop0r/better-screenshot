import AppKit

enum Shape {
    case freehand([CGPoint])
    case line(CGPoint, CGPoint)
    case arrow(CGPoint, CGPoint)
    case rect(CGRect)
    case ellipse(CGRect)
    case text(origin: CGPoint, string: String, size: CGFloat)
    case number(center: CGPoint, value: Int, size: CGFloat)
    case mosaic(CGRect)
}

struct Item {
    var id = UUID()
    var shape: Shape
    var color: NSColor
    var width: CGFloat
    var opacity: CGFloat = 1
    var highlighter = false
}

func textFont(_ size: CGFloat) -> NSFont { .systemFont(ofSize: size, weight: .semibold) }

func boundingBox(_ pts: [CGPoint]) -> CGRect {
    guard let f = pts.first else { return .zero }
    var minX = f.x, maxX = f.x, minY = f.y, maxY = f.y
    for p in pts {
        minX = min(minX, p.x); maxX = max(maxX, p.x)
        minY = min(minY, p.y); maxY = max(maxY, p.y)
    }
    return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
}

func dist(_ a: CGPoint, _ b: CGPoint) -> CGFloat { hypot(a.x - b.x, a.y - b.y) }

func distToSegment(_ p: CGPoint, _ a: CGPoint, _ b: CGPoint) -> CGFloat {
    let dx = b.x - a.x, dy = b.y - a.y
    let l2 = dx * dx + dy * dy
    if l2 == 0 { return dist(p, a) }
    let t = max(0, min(1, ((p.x - a.x) * dx + (p.y - a.y) * dy) / l2))
    return dist(p, CGPoint(x: a.x + t * dx, y: a.y + t * dy))
}

extension Item {
    var bounds: CGRect {
        switch shape {
        case .freehand(let pts): return boundingBox(pts)
        case .line(let a, let b), .arrow(let a, let b): return boundingBox([a, b])
        case .rect(let r), .ellipse(let r), .mosaic(let r): return r.standardized
        case .text(let o, let s, let size):
            let sz = (s as NSString).size(withAttributes: [.font: textFont(size)])
            return CGRect(origin: o, size: sz)
        case .number(let c, _, let size):
            let d = size * 1.7
            return CGRect(x: c.x - d / 2, y: c.y - d / 2, width: d, height: d)
        }
    }

    func hit(_ p: CGPoint, tolerance t: CGFloat) -> Bool {
        let tol = t + width / 2
        switch shape {
        case .freehand(let pts):
            if pts.count == 1 { return dist(p, pts[0]) <= tol }
            for i in 1..<pts.count where distToSegment(p, pts[i - 1], pts[i]) <= tol { return true }
            return false
        case .line(let a, let b), .arrow(let a, let b):
            return distToSegment(p, a, b) <= tol
        case .rect(let r), .ellipse(let r):
            let rr = r.standardized
            return rr.insetBy(dx: -tol, dy: -tol).contains(p) && !rr.insetBy(dx: tol, dy: tol).contains(p)
        case .mosaic, .text, .number:
            return bounds.insetBy(dx: -t, dy: -t).contains(p)
        }
    }

    func translated(dx: CGFloat, dy: CGFloat) -> Item {
        var c = self
        func m(_ p: CGPoint) -> CGPoint { CGPoint(x: p.x + dx, y: p.y + dy) }
        switch shape {
        case .freehand(let pts): c.shape = .freehand(pts.map(m))
        case .line(let a, let b): c.shape = .line(m(a), m(b))
        case .arrow(let a, let b): c.shape = .arrow(m(a), m(b))
        case .rect(let r): c.shape = .rect(r.offsetBy(dx: dx, dy: dy))
        case .ellipse(let r): c.shape = .ellipse(r.offsetBy(dx: dx, dy: dy))
        case .mosaic(let r): c.shape = .mosaic(r.offsetBy(dx: dx, dy: dy))
        case .text(let o, let s, let size): c.shape = .text(origin: m(o), string: s, size: size)
        case .number(let ce, let v, let size): c.shape = .number(center: m(ce), value: v, size: size)
        }
        return c
    }
}

struct EditorState {
    var image: CGImage
    var items: [Item]
}

final class EditorDocument {
    private(set) var state: EditorState
    private var undoStack: [EditorState] = []
    private var redoStack: [EditorState] = []
    /// Backing scale of the screen the image was captured on; line widths are scaled by it.
    let unit: CGFloat
    var onChange: (() -> Void)?

    init(image: CGImage, unit: CGFloat) {
        self.state = EditorState(image: image, items: [])
        self.unit = unit
    }

    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }

    func commit(_ new: EditorState) {
        undoStack.append(state)
        redoStack.removeAll()
        state = new
        onChange?()
    }

    /// Live (non-undoable) update, used while dragging; call `pushUndo` with the pre-drag state afterwards.
    func setLive(_ new: EditorState) {
        state = new
        onChange?()
    }

    func pushUndo(_ old: EditorState) {
        undoStack.append(old)
        redoStack.removeAll()
        onChange?()
    }

    func undo() {
        guard let p = undoStack.popLast() else { return }
        redoStack.append(state)
        state = p
        onChange?()
    }

    func redo() {
        guard let n = redoStack.popLast() else { return }
        undoStack.append(state)
        state = n
        onChange?()
    }
}
