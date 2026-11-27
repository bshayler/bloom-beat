import SwiftUI

private let white = RGB(1, 1, 1)
private let black = RGB(0, 0, 0)

private func bez(_ p0: CGPoint, _ p1: CGPoint, _ p2: CGPoint, _ p3: CGPoint, _ t: Double) -> CGPoint {
    let u = 1 - t
    let a = u * u * u, b = 3 * u * u * t, c = 3 * u * t * t, d = t * t * t
    return CGPoint(x: a * p0.x + b * p1.x + c * p2.x + d * p3.x,
                   y: a * p0.y + b * p1.y + c * p2.y + d * p3.y)
}

/// A real leaf: asymmetric, gently curved, pointed tip. `half` -1 = left half only, +1 = right half only.
func leafPath(_ len: Double, half: Int = 0) -> Path {
    let L = len
    var p = Path()
    p.move(to: .zero)
    if half <= 0 {
        // left edge up to the tip
        p.addCurve(to: CGPoint(x: 0.05 * L, y: -L), control1: CGPoint(x: -0.40 * L, y: -0.08 * L), control2: CGPoint(x: -0.33 * L, y: -0.64 * L))
    } else {
        p.addLine(to: CGPoint(x: 0.05 * L, y: -L))
    }
    if half >= 0 {
        // right edge back down to the base
        if half > 0 { p.move(to: CGPoint(x: 0.05 * L, y: -L)) }
        p.addCurve(to: .zero, control1: CGPoint(x: 0.47 * L, y: -0.62 * L), control2: CGPoint(x: 0.43 * L, y: -0.08 * L))
    }
    p.closeSubpath()
    return p
}

/// Midrib and side veins for a leaf of the given length.
func leafVeins(_ len: Double) -> Path {
    let L = len
    var v = Path()
    v.move(to: .zero)
    v.addQuadCurve(to: CGPoint(x: 0.05 * L, y: -0.94 * L), control: CGPoint(x: 0.0, y: -0.5 * L))
    for f in [0.28, 0.48, 0.68] {
        let y = -f * L
        let x = 0.012 * L * (f * 4)
        let reach = (0.30 - 0.28 * f) * L
        v.move(to: CGPoint(x: x, y: y))
        v.addQuadCurve(to: CGPoint(x: x + reach, y: y - 0.14 * L), control: CGPoint(x: x + reach * 0.5, y: y - 0.03 * L))
        v.move(to: CGPoint(x: x, y: y))
        v.addQuadCurve(to: CGPoint(x: x - reach, y: y - 0.14 * L), control: CGPoint(x: x - reach * 0.5, y: y - 0.03 * L))
    }
    return v
}

private extension GraphicsContext {
    mutating func translateTo(top: CGPoint, angle: Double) {
        translateBy(x: top.x, y: top.y)
        rotate(by: .radians(angle))
    }
}

private func lin(_ colors: [Color], _ a: CGPoint, _ b: CGPoint) -> GraphicsContext.Shading {
    .linearGradient(Gradient(colors: colors), startPoint: a, endPoint: b)
}
private func rad(_ colors: [Color], _ c: CGPoint, _ r0: Double, _ r1: Double) -> GraphicsContext.Shading {
    .radialGradient(Gradient(colors: colors), center: c, startRadius: r0, endRadius: r1)
}

/// Draws the potted plant. `health` 0...1 picks growth stage; `wilt` 0...1 droops and fades it.
func drawPlant(_ ctx: GraphicsContext, rect: CGRect, health h: Double, wilt w: Double,
               time: Double, pop: Double, flower: Int = 3) {
    var g = ctx
    let potW = min(rect.width * 0.26, rect.height * 0.36)
    let potH = potW * 0.62
    let cx = rect.midX
    let potTop = rect.maxY - potH
    let headroom = min(104, rect.height * 0.40)
    let maxH = max(40, rect.height - potH - 14 - headroom)

    // ground shadow
    g.fill(Path(ellipseIn: CGRect(x: cx - potW * 0.75, y: rect.maxY - potH * 0.10, width: potW * 1.5, height: potH * 0.22)),
           with: .color(.black.opacity(0.22)))

    // pot (shaded cylinder look)
    let potBase = RGB(0.82, 0.43, 0.28).mixed(RGB(0.62, 0.50, 0.42), w * 0.5)
    var body = Path()
    body.move(to: CGPoint(x: cx - potW * 0.5, y: potTop + potH * 0.22))
    body.addLine(to: CGPoint(x: cx + potW * 0.5, y: potTop + potH * 0.22))
    body.addLine(to: CGPoint(x: cx + potW * 0.38, y: rect.maxY))
    body.addQuadCurve(to: CGPoint(x: cx - potW * 0.38, y: rect.maxY), control: CGPoint(x: cx, y: rect.maxY + potH * 0.08))
    body.closeSubpath()
    g.fill(body, with: lin([potBase.mixed(white, 0.28).color, potBase.color, potBase.mixed(black, 0.32).color],
                           CGPoint(x: cx - potW * 0.5, y: 0), CGPoint(x: cx + potW * 0.5, y: 0)))
    // sheen
    var sheen = Path()
    sheen.move(to: CGPoint(x: cx - potW * 0.30, y: potTop + potH * 0.32))
    sheen.addLine(to: CGPoint(x: cx - potW * 0.20, y: potTop + potH * 0.32))
    sheen.addLine(to: CGPoint(x: cx - potW * 0.17, y: rect.maxY - potH * 0.12))
    sheen.addLine(to: CGPoint(x: cx - potW * 0.24, y: rect.maxY - potH * 0.12))
    sheen.closeSubpath()
    g.fill(sheen, with: .color(.white.opacity(0.16)))
    let rim = CGRect(x: cx - potW * 0.58, y: potTop, width: potW * 1.16, height: potH * 0.27)
    g.fill(Path(roundedRect: rim, cornerRadius: potH * 0.10),
           with: lin([potBase.mixed(white, 0.38).color, potBase.mixed(white, 0.05).color, potBase.mixed(black, 0.22).color],
                     CGPoint(x: cx - potW * 0.58, y: 0), CGPoint(x: cx + potW * 0.58, y: 0)))
    g.fill(Path(roundedRect: CGRect(x: rim.minX + 4, y: rim.minY + 2, width: rim.width - 8, height: 3), cornerRadius: 1.5),
           with: .color(.white.opacity(0.35)))
    // soil
    let soil = CGRect(x: cx - potW * 0.5, y: potTop - potH * 0.03, width: potW, height: potH * 0.15)
    g.fill(Path(ellipseIn: soil), with: rad([RGB(0.42, 0.28, 0.18).color, RGB(0.24, 0.15, 0.09).color],
                                            CGPoint(x: cx, y: soil.midY), 1, potW * 0.5))
    let baseY = potTop + potH * 0.04

    // stem geometry
    let grow = smooth(0, 0.70, h)
    let stemH = maxH * (0.12 + 0.88 * grow)
    let sway = sin(time * 1.4) * 0.03 * (1 - w)
    let p0 = CGPoint(x: cx, y: baseY)
    let top = CGPoint(x: cx + stemH * (sway + 0.55 * w), y: baseY - stemH * (1 - 0.45 * w))
    let p1 = CGPoint(x: cx, y: baseY - stemH * 0.6)
    let p2 = CGPoint(x: top.x - w * 0.45 * stemH, y: top.y + (0.25 - 0.40 * w) * stemH)
    let tangent = atan2(top.y - p2.y, top.x - p2.x)
    let headAngle = tangent + Double.pi / 2

    let stemC = RGB(0.30, 0.68, 0.32).mixed(RGB(0.60, 0.55, 0.28), w)
    let leafC = RGB(0.38, 0.78, 0.38).mixed(RGB(0.64, 0.52, 0.25), w)

    var stem = Path()
    stem.move(to: p0)
    stem.addCurve(to: top, control1: p1, control2: p2)
    let sw = 3 + 4 * grow
    g.stroke(stem, with: .color(stemC.mixed(black, 0.40).color), style: StrokeStyle(lineWidth: sw + 1.5, lineCap: .round))
    g.stroke(stem, with: .color(stemC.color), style: StrokeStyle(lineWidth: sw, lineCap: .round))
    var hl = g
    hl.translateBy(x: -sw * 0.22, y: 0)
    hl.stroke(stem, with: .color(stemC.mixed(white, 0.45).color.opacity(0.75)),
              style: StrokeStyle(lineWidth: max(1, sw * 0.28), lineCap: .round))

    // leaves (two-tone fold + drop shadow)
    let leaves: [(Double, Double, Double)] = [
        (0.20, -1, 0.18), (0.34, 1, 0.18), (0.48, -1, 0.34), (0.61, 1, 0.34), (0.74, -1, 0.50)
    ]
    func drawLeaf(at pt: CGPoint, side: Double, len: Double) {
        guard len > 1 else { return }
        var lc = g
        lc.translateBy(x: pt.x, y: pt.y)
        lc.rotate(by: .radians(side * (1.05 + 0.85 * w) + sway * 2))
        // short stalk, then the leaf blade
        var stalk = Path(); stalk.move(to: .zero); stalk.addLine(to: CGPoint(x: 0, y: -len * 0.14))
        lc.stroke(stalk, with: .color(stemC.color), style: StrokeStyle(lineWidth: max(1, len * 0.06), lineCap: .round))
        lc.translateBy(x: 0, y: -len * 0.14)
        var sh = lc
        sh.translateBy(x: 2, y: 3)
        sh.fill(leafPath(len), with: .color(.black.opacity(0.18)))
        lc.fill(leafPath(len), with: lin([leafC.mixed(black, 0.05).color, leafC.mixed(black, 0.32).color],
                                         CGPoint(x: -len * 0.4, y: 0), CGPoint(x: len * 0.4, y: 0)))
        lc.fill(leafPath(len, half: -1), with: lin([leafC.mixed(white, 0.30).color, leafC.mixed(white, 0.05).color],
                                                    CGPoint(x: -len * 0.4, y: -len), CGPoint(x: 0, y: 0)))
        lc.stroke(leafPath(len), with: .color(leafC.mixed(black, 0.42).color.opacity(0.7)), lineWidth: 0.8)
        lc.stroke(leafVeins(len), with: .color(leafC.mixed(black, 0.35).color.opacity(0.75)), style: StrokeStyle(lineWidth: max(0.6, len * 0.035), lineCap: .round))
    }
    for (t, side, minH) in leaves {
        let sc = smooth(minH, minH + 0.07, h) * (0.6 + 0.4 * grow)
        drawLeaf(at: bez(p0, p1, p2, top, t), side: side, len: (18 + 30 * grow) * sc)
    }
    let topPair = 1 - smooth(0.34, 0.50, h)
    if topPair > 0.01 {
        let len = (11 + 12 * grow) * topPair
        let pt = bez(p0, p1, p2, top, 0.97)
        drawLeaf(at: pt, side: -1, len: len)
        drawLeaf(at: pt, side: 1, len: len)
    }

    // flower head: bud first, then ONE flower type that grows from small to big
    if h >= 0.34 {
        let bases: [Double: Double] = [3: 30, 4: 30, 5: 34, 6: 38]
        let stage: Int
        let R: Double
        if h < 0.5 {
            stage = 2
            R = 15 * (0.55 + 0.45 * smooth(0.34, 0.5, h)) * (1 + 0.35 * pop) * (1 - 0.12 * w)
        } else {
            stage = flower
            let size = 0.42 + 0.9 * smooth(0.5, 1.0, h)
            R = (bases[Double(flower)] ?? 30) * size * (1 + 0.35 * pop) * (1 - 0.12 * w)
        }
        var hc = g
        hc.translateTo(top: top, angle: headAngle)
        let tilt = 0.86 + 0.08 * sin(time * 0.9) * (1 - w)
        drawFlowerHead(hc, stage: stage, R: R, w: w, tilt: tilt, flower: flower)
    }
}

private func drawFlowerHead(_ ctx: GraphicsContext, stage: Int, R: Double, w: Double, tilt: Double, flower: Int) {
    var g = ctx
    func t(_ c: RGB) -> RGB { c.mixed(RGB(0.55, 0.42, 0.27), w * 0.75) }
    func tc(_ c: RGB) -> Color { t(c).color }
    let tau = 2 * Double.pi

    func dropShadow(_ rx: Double, _ ry: Double, _ cy: Double) {
        g.fill(Path(ellipseIn: CGRect(x: -rx + R * 0.10, y: cy - ry + R * 0.16, width: rx * 2, height: ry * 2)),
               with: .radialGradient(Gradient(colors: [.black.opacity(0.14), .clear]),
                                     center: CGPoint(x: R * 0.10, y: cy + R * 0.16), startRadius: 1, endRadius: max(rx, ry)))
    }

    switch stage {
    case 2: // bud, tinted like the flower it will become
        let bc: RGB
        switch flower {
        case 4: bc = RGB(0.90, 0.22, 0.32)
        case 5: bc = RGB(0.98, 0.62, 0.76)
        case 6: bc = RGB(0.72, 0.80, 0.22)
        default: bc = RGB(0.98, 0.86, 0.90)
        }
        g.translateBy(x: 0, y: -R * 1.2)
        dropShadow(R * 0.8, R * 1.1, 0)
        let rect = CGRect(x: -R * 0.75, y: -R * 1.1, width: R * 1.5, height: R * 2.2)
        g.fill(Path(ellipseIn: rect), with: rad([tc(bc.mixed(white, 0.55)), tc(bc), tc(bc.mixed(black, 0.35))],
                                               CGPoint(x: -R * 0.28, y: -R * 0.4), 1, R * 1.4))
        var seam = Path()
        seam.move(to: CGPoint(x: 0, y: -R * 1.1))
        seam.addQuadCurve(to: CGPoint(x: 0, y: R * 1.1), control: CGPoint(x: R * 0.5, y: 0))
        g.stroke(seam, with: .color(tc(bc.mixed(black, 0.3)).opacity(0.8)), lineWidth: 1.4)
        g.fill(Path(ellipseIn: CGRect(x: -R * 0.42, y: -R * 0.85, width: R * 0.32, height: R * 0.6)),
               with: .color(.white.opacity(0.4)))
        for sd in [-1.0, 1.0] {
            var sp = Path()
            sp.move(to: CGPoint(x: 0, y: R * 1.1))
            sp.addQuadCurve(to: CGPoint(x: sd * R * 0.9, y: R * 0.1), control: CGPoint(x: sd * R * 0.8, y: R * 1.0))
            sp.addQuadCurve(to: CGPoint(x: 0, y: R * 1.1), control: CGPoint(x: sd * R * 0.3, y: R * 0.5))
            g.fill(sp, with: lin([tc(RGB(0.45, 0.82, 0.42)), tc(RGB(0.22, 0.52, 0.25))],
                                 CGPoint(x: 0, y: 0), CGPoint(x: sd * R, y: R)))
        }

    case 3: // daisy
        g.translateBy(x: 0, y: -R * 0.95)
        g.scaleBy(x: 1, y: tilt)
        dropShadow(R * 1.05, R * 1.05, 0)
        for ring in 0..<2 {
            let n = 14
            for i in 0..<n {
                var p = g
                p.rotate(by: .radians((Double(i) + (ring == 0 ? 0.5 : 0)) / Double(n) * tau))
                let len = ring == 0 ? R * 0.95 : R
                let petal = Path(ellipseIn: CGRect(x: -R * 0.125, y: -len, width: R * 0.25, height: len - R * 0.28))
                let base = ring == 0 ? RGB(0.86, 0.84, 0.82) : RGB(0.99, 0.98, 0.97)
                p.fill(petal, with: lin([tc(white), tc(base), tc(base.mixed(RGB(0.7, 0.6, 0.7), 0.25))],
                                        CGPoint(x: -R * 0.1, y: -len), CGPoint(x: R * 0.1, y: -R * 0.3)))
                var crease = Path()
                crease.move(to: CGPoint(x: 0, y: -R * 0.32)); crease.addLine(to: CGPoint(x: 0, y: -len * 0.9))
                p.stroke(crease, with: .color(tc(RGB(0.80, 0.75, 0.80)).opacity(0.7)), lineWidth: 0.7)
            }
        }
        let c = CGRect(x: -R * 0.35, y: -R * 0.35, width: R * 0.7, height: R * 0.7)
        g.fill(Path(ellipseIn: c), with: rad([tc(RGB(1.0, 0.95, 0.5)), tc(RGB(1.0, 0.78, 0.15)), tc(RGB(0.85, 0.50, 0.08))],
                                             CGPoint(x: -R * 0.1, y: -R * 0.12), 1, R * 0.45))
        for i in 0..<14 {
            let r = R * 0.24 * (Double(i) / 14).squareRoot()
            let a = Double(i) * 2.39996
            g.fill(Path(ellipseIn: CGRect(x: cos(a) * r - 1, y: sin(a) * r - 1, width: 2, height: 2)),
                   with: .color(tc(RGB(0.75, 0.42, 0.05)).opacity(0.8)))
        }
        g.fill(Path(ellipseIn: CGRect(x: -R * 0.2, y: -R * 0.26, width: R * 0.2, height: R * 0.12)), with: .color(.white.opacity(0.55)))

    case 4: // tulip
        dropShadow(R * 0.9, R * 1.0, -R * 1.0)
        let deep = RGB(0.70, 0.08, 0.22), mid = RGB(0.92, 0.22, 0.34), lite = RGB(1.0, 0.55, 0.60)
        // back petals
        for sd in [-1.0, 1.0] {
            var p = Path()
            p.move(to: CGPoint(x: 0, y: 0))
            p.addQuadCurve(to: CGPoint(x: sd * R * 0.5, y: -R * 2.05), control: CGPoint(x: sd * R * 1.25, y: -R * 0.7))
            p.addQuadCurve(to: .zero, control: CGPoint(x: sd * R * 0.2, y: -R * 1.2))
            g.fill(p, with: lin([tc(mid), tc(deep)], CGPoint(x: sd * R, y: -R), CGPoint(x: 0, y: 0)))
        }
        // front cup
        var cup = Path()
        cup.move(to: CGPoint(x: -R * 0.62, y: -R * 0.05))
        cup.addQuadCurve(to: CGPoint(x: -R * 0.3, y: -R * 1.95), control: CGPoint(x: -R * 0.85, y: -R * 1.1))
        cup.addLine(to: CGPoint(x: 0, y: -R * 1.55))
        cup.addLine(to: CGPoint(x: R * 0.3, y: -R * 1.95))
        cup.addQuadCurve(to: CGPoint(x: R * 0.62, y: -R * 0.05), control: CGPoint(x: R * 0.85, y: -R * 1.1))
        cup.addQuadCurve(to: CGPoint(x: -R * 0.62, y: -R * 0.05), control: CGPoint(x: 0, y: R * 0.22))
        g.fill(cup, with: rad([tc(lite), tc(mid), tc(deep)], CGPoint(x: -R * 0.25, y: -R * 1.0), 1, R * 1.4))
        var edge = Path()
        edge.move(to: CGPoint(x: 0, y: -R * 1.55)); edge.addQuadCurve(to: CGPoint(x: 0, y: -R * 0.1), control: CGPoint(x: R * 0.25, y: -R * 0.8))
        g.stroke(edge, with: .color(tc(deep).opacity(0.5)), lineWidth: 1.2)
        g.fill(Path(ellipseIn: CGRect(x: -R * 0.5, y: -R * 1.5, width: R * 0.25, height: R * 0.8)), with: .color(.white.opacity(0.28)))

    case 5: // cherry blossom
        g.translateBy(x: 0, y: -R * 1.0)
        g.scaleBy(x: 1, y: tilt)
        dropShadow(R * 1.1, R * 1.1, 0)
        for layer in 0..<2 {
            for i in 0..<5 {
                let a = (Double(i) + (layer == 0 ? 0.5 : 0)) / 5 * tau
                var p = g
                p.rotate(by: .radians(a))
                let L = layer == 0 ? R * 0.92 : R
                var petal = Path()
                petal.move(to: CGPoint(x: 0, y: -R * 0.1))
                petal.addQuadCurve(to: CGPoint(x: -R * 0.16, y: -L), control: CGPoint(x: -R * 0.72, y: -L * 0.75))
                petal.addQuadCurve(to: CGPoint(x: 0, y: -L * 0.88), control: CGPoint(x: -R * 0.06, y: -L * 0.98))
                petal.addQuadCurve(to: CGPoint(x: R * 0.16, y: -L), control: CGPoint(x: R * 0.06, y: -L * 0.98))
                petal.addQuadCurve(to: CGPoint(x: 0, y: -R * 0.1), control: CGPoint(x: R * 0.72, y: -L * 0.75))
                let pk = layer == 0 ? RGB(0.98, 0.62, 0.74) : RGB(1.0, 0.80, 0.87)
                p.fill(petal, with: rad([tc(RGB(0.92, 0.38, 0.58)), tc(pk), tc(pk.mixed(white, 0.55))],
                                        CGPoint(x: 0, y: -R * 0.1), 1, L))
                p.stroke(petal, with: .color(tc(RGB(0.93, 0.50, 0.66)).opacity(0.55)), lineWidth: 0.8)
            }
        }
        g.fill(Path(ellipseIn: CGRect(x: -R * 0.22, y: -R * 0.22, width: R * 0.44, height: R * 0.44)),
               with: rad([tc(RGB(1.0, 0.9, 0.5)), tc(RGB(0.90, 0.35, 0.55))], .zero, 1, R * 0.25))
        for i in 0..<9 {
            let a = Double(i) / 9 * tau
            var ray = Path()
            ray.move(to: .zero)
            ray.addLine(to: CGPoint(x: sin(a) * R * 0.46, y: -cos(a) * R * 0.46))
            g.stroke(ray, with: .color(tc(RGB(0.90, 0.40, 0.58))), lineWidth: 0.9)
            g.fill(Path(ellipseIn: CGRect(x: sin(a) * R * 0.46 - 2.2, y: -cos(a) * R * 0.46 - 2.2, width: 4.4, height: 4.4)),
                   with: rad([tc(RGB(1.0, 0.95, 0.6)), tc(RGB(0.95, 0.65, 0.15))], CGPoint(x: sin(a) * R * 0.46 - 0.5, y: -cos(a) * R * 0.46 - 0.5), 0.5, 3))
        }

    default: // sunflower
        g.translateBy(x: 0, y: -R * 1.0)
        g.scaleBy(x: 1, y: tilt)
        dropShadow(R * 1.1, R * 1.1, 0)
        let rings: [(Int, Double, Double, RGB, RGB)] = [
            (20, 1.00, 0.0, RGB(1.0, 0.86, 0.15), RGB(0.95, 0.55, 0.05)),
            (20, 0.84, 0.5, RGB(1.0, 0.76, 0.10), RGB(0.90, 0.48, 0.03))
        ]
        for (count, lenK, off, tipC, baseC) in rings {
            let len = R * lenK
            for i in 0..<count {
                var p = g
                p.rotate(by: .radians((Double(i) + off) / Double(count) * tau))
                var petal = Path()
                petal.move(to: CGPoint(x: 0, y: -R * 0.28))
                petal.addQuadCurve(to: CGPoint(x: 0, y: -len), control: CGPoint(x: R * 0.30, y: -len * 0.72))
                petal.addQuadCurve(to: CGPoint(x: 0, y: -R * 0.28), control: CGPoint(x: -R * 0.30, y: -len * 0.72))
                p.fill(petal, with: lin([tc(tipC), tc(baseC)], CGPoint(x: 0, y: -len), CGPoint(x: 0, y: -R * 0.3)))
                var vein = Path()
                vein.move(to: CGPoint(x: 0, y: -R * 0.32)); vein.addLine(to: CGPoint(x: 0, y: -len * 0.85))
                p.stroke(vein, with: .color(tc(baseC).opacity(0.6)), lineWidth: 0.7)
            }
        }
        let disc = CGRect(x: -R * 0.46, y: -R * 0.46, width: R * 0.92, height: R * 0.92)
        g.fill(Path(ellipseIn: disc), with: rad([tc(RGB(0.55, 0.34, 0.14)), tc(RGB(0.32, 0.18, 0.07)), tc(RGB(0.16, 0.09, 0.03))],
                                                CGPoint(x: -R * 0.12, y: -R * 0.14), 1, R * 0.55))
        for i in 0..<46 {
            let r = R * 0.43 * (Double(i) / 46).squareRoot()
            let a = Double(i) * 2.39996
            let c = CGPoint(x: cos(a) * r, y: sin(a) * r)
            g.fill(Path(ellipseIn: CGRect(x: c.x - 1.6, y: c.y - 1.2, width: 3.2, height: 3.2)), with: .color(.black.opacity(0.35)))
            g.fill(Path(ellipseIn: CGRect(x: c.x - 1.6, y: c.y - 1.6, width: 3.0, height: 3.0)),
                   with: .color(tc(RGB(0.62, 0.40, 0.18))))
        }
        g.fill(Path(ellipseIn: CGRect(x: -R * 0.30, y: -R * 0.38, width: R * 0.30, height: R * 0.16)), with: .color(.white.opacity(0.25)))
    }
}

/// A standalone plant canvas for the menu and result screens.
struct PlantPreview: View {
    var health: Double = 0.5
    var wilt: Double = 0
    var cycle = false
    var compact = false   // draw at menu proportions, scaled to fit small cells
    var flower = 3
    var use3D = true      // false forces the 2D canvas
    var still = false     // true shows a cached picture of the 3D plant instead of a live view (shelf grid)

    var body: some View {
        if use3D && PlantRendering.enabled {
            if still {
                PlantSnapshotView(health: health, wilt: wilt, flower: flower)
            } else {
                PlantSceneView(health: health, wilt: wilt, flower: flower, cycle: cycle)
            }
        } else {
            canvasBody
        }
    }

    private var canvasBody: some View {
        TimelineView(.animation) { tl in
            let t = tl.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                var h = health
                var pop = 0.0
                var fl = flower
                if cycle {
                    let period = 16.0
                    fl = 3 + Int(t / period) % 4
                    let phase = t.truncatingRemainder(dividingBy: period) / period
                    h = 0.08 + 0.92 * min(1, phase / 0.9)
                    let st = PlantStage.index(for: h)
                    let stageStart = PlantStage.thresholds[st]
                    pop = exp(-(h - stageStart) * 40) * (st > 0 ? 1 : 0)
                }
                if compact {
                    let sc = size.height / 260
                    var c = ctx
                    c.translateBy(x: size.width / 2 - 175 * sc, y: 0)
                    c.scaleBy(x: sc, y: sc)
                    drawPlant(c, rect: CGRect(x: 0, y: 0, width: 350, height: 260), health: h, wilt: wilt, time: t, pop: pop, flower: fl)
                } else {
                    drawPlant(ctx, rect: CGRect(origin: .zero, size: size), health: h, wilt: wilt, time: t, pop: pop, flower: fl)
                }
            }
        }
    }
}
