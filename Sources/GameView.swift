import SwiftUI
import UIKit

// MARK: - Multi-touch input (low latency, hardware timestamps, begin + end for holds)

final class TouchUIView: UIView {
    var began: ((ObjectIdentifier, CGPoint, TimeInterval) -> Void)?
    var ended: ((ObjectIdentifier, TimeInterval) -> Void)?
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for t in touches { began?(ObjectIdentifier(t), t.location(in: self), t.timestamp) }
    }
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        for t in touches { ended?(ObjectIdentifier(t), t.timestamp) }
    }
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        for t in touches { ended?(ObjectIdentifier(t), t.timestamp) }
    }
}

struct TouchPad: UIViewRepresentable {
    var began: (ObjectIdentifier, CGPoint, TimeInterval) -> Void
    var ended: (ObjectIdentifier, TimeInterval) -> Void
    func makeUIView(context: Context) -> TouchUIView {
        let v = TouchUIView()
        v.isMultipleTouchEnabled = true
        v.backgroundColor = .clear
        v.began = began; v.ended = ended
        return v
    }
    func updateUIView(_ v: TouchUIView, context: Context) { v.began = began; v.ended = ended }
}

// MARK: - Game screen

struct GameView: View {
    @ObservedObject var engine: GameEngine

    var body: some View {
        GeometryReader { outer in
            let ins = outer.safeAreaInsets
            let full = CGSize(width: outer.size.width + ins.leading + ins.trailing,
                              height: outer.size.height + ins.top + ins.bottom)
            ZStack(alignment: .topTrailing) {
                TimelineView(.animation) { tl in
                    let t = tl.date.timeIntervalSinceReferenceDate
                    Canvas { ctx, size in
                        GameRenderer.draw(&ctx, size: size, engine: engine, time: t)
                    }
                }
                TouchPad(began: { id, pt, ts in engine.touchBegan(id: id, at: pt, timestamp: ts) },
                         ended: { id, ts in engine.touchEnded(id: id, timestamp: ts) })

                Button {
                    engine.pause()
                } label: {
                    Image(systemName: "pause.fill")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 42, height: 42)
                        .background(Circle().fill(.black.opacity(0.30)))
                        .overlay(Circle().stroke(.white.opacity(0.35), lineWidth: 1.5))
                }
                .padding(.top, ins.top + 4)
                .padding(.trailing, 14)
            }
            .frame(width: full.width, height: full.height)
            .offset(x: -ins.leading, y: -ins.top)
            .onAppear { engine.setLayout(size: full, top: ins.top, bottom: ins.bottom) }
            .onChange(of: full) { _ in engine.setLayout(size: full, top: ins.top, bottom: ins.bottom) }
        }
    }
}

// MARK: - Shared scenery (used by game and menu)

func drawText(_ ctx: inout GraphicsContext, _ s: String, at p: CGPoint, size: CGFloat, color: Color,
              weight: Font.Weight = .heavy, anchor: UnitPoint = .center, shadow: Bool = true, mono: Bool = false) {
    var f = Font.system(size: size, weight: weight, design: .rounded)
    if mono { f = f.monospacedDigit() }
    if shadow {
        ctx.draw(Text(s).font(f).foregroundColor(.black.opacity(0.35)), at: CGPoint(x: p.x, y: p.y + 2), anchor: anchor)
    }
    ctx.draw(Text(s).font(f).foregroundColor(color), at: p, anchor: anchor)
}

func drawScenery(_ ctx: inout GraphicsContext, size: CGSize, groundY: CGFloat, wilt w: Double, time: Double) {
    let skyTop = RGB(0.36, 0.64, 0.96).mixed(RGB(0.52, 0.54, 0.60), w * 0.85)
    let skyMid = RGB(0.62, 0.84, 0.98).mixed(RGB(0.64, 0.64, 0.66), w * 0.85)
    let skyBot = RGB(1.00, 0.95, 0.82).mixed(RGB(0.78, 0.74, 0.68), w * 0.85)
    ctx.fill(Path(CGRect(origin: .zero, size: size)),
             with: .linearGradient(Gradient(stops: [.init(color: skyTop.color, location: 0),
                                                    .init(color: skyMid.color, location: 0.55),
                                                    .init(color: skyBot.color, location: 1)]),
                                   startPoint: .zero, endPoint: CGPoint(x: 0, y: groundY)))

    // sun with soft glow and slowly turning rays
    let sun = CGPoint(x: size.width * 0.80, y: groundY * 0.40)
    let sunA = 1 - w * 0.75
    ctx.fill(Path(ellipseIn: CGRect(x: sun.x - 130, y: sun.y - 130, width: 260, height: 260)),
             with: .radialGradient(Gradient(colors: [Color(red: 1, green: 0.95, blue: 0.7).opacity(0.75 * sunA), .clear]),
                                   center: sun, startRadius: 6, endRadius: 130))
    var rays = ctx
    rays.translateBy(x: sun.x, y: sun.y)
    rays.rotate(by: .radians(time * 0.05))
    for i in 0..<12 {
        var r = rays
        r.rotate(by: .radians(Double(i) / 12 * 2 * Double.pi))
        var tri = Path()
        tri.move(to: CGPoint(x: -7, y: -34)); tri.addLine(to: CGPoint(x: 0, y: -78)); tri.addLine(to: CGPoint(x: 7, y: -34))
        r.fill(tri, with: .color(Color(red: 1, green: 0.93, blue: 0.55).opacity(0.35 * sunA)))
    }
    ctx.fill(Path(ellipseIn: CGRect(x: sun.x - 26, y: sun.y - 26, width: 52, height: 52)),
             with: .radialGradient(Gradient(colors: [Color(red: 1, green: 0.98, blue: 0.82).opacity(sunA), Color(red: 1, green: 0.85, blue: 0.35).opacity(sunA)]),
                                   center: CGPoint(x: sun.x - 6, y: sun.y - 6), startRadius: 1, endRadius: 30))

    // clouds
    for k in 0..<4 {
        let span = Double(size.width) + 260
        let x = (time * (4 + Double(k) * 2.5) + Double(k) * 190).truncatingRemainder(dividingBy: span) - 130
        let y = Double(groundY) * (0.18 + 0.16 * Double(k % 3)) + 20
        let a = 0.85 * (1 - w * 0.55)
        let sc = 0.8 + Double(k % 3) * 0.25
        for (dx, dy, r) in [(0.0, 0.0, 16.0), (18.0, -9.0, 22.0), (40.0, -2.0, 18.0), (58.0, 3.0, 13.0)] {
            ctx.fill(Path(ellipseIn: CGRect(x: x + dx * sc - r * sc, y: y + dy * sc - r * sc * 0.7, width: r * 2 * sc, height: r * 1.4 * sc)),
                     with: .linearGradient(Gradient(colors: [.white.opacity(a), Color(red: 0.88, green: 0.93, blue: 1).opacity(a)]),
                                           startPoint: CGPoint(x: x, y: y - 20), endPoint: CGPoint(x: x, y: y + 14)))
        }
    }

    // layered hills
    func hill(_ base: CGFloat, _ amp: CGFloat, _ freq: Double, _ phase: Double, _ top: RGB, _ bot: RGB) {
        var p = Path()
        p.move(to: CGPoint(x: 0, y: groundY + 4))
        let steps = 28
        for i in 0...steps {
            let x = size.width * CGFloat(i) / CGFloat(steps)
            let y = base + amp * CGFloat(sin(Double(x) / Double(size.width) * freq * 2 * Double.pi + phase))
            p.addLine(to: CGPoint(x: x, y: y))
        }
        p.addLine(to: CGPoint(x: size.width, y: groundY + 4))
        p.closeSubpath()
        ctx.fill(p, with: .linearGradient(Gradient(colors: [top.mixed(RGB(0.62, 0.58, 0.5), w * 0.7).color, bot.mixed(RGB(0.5, 0.48, 0.42), w * 0.7).color]),
                                          startPoint: CGPoint(x: 0, y: base - amp), endPoint: CGPoint(x: 0, y: groundY)))
    }
    hill(groundY - 70, 18, 1.0, 0.6, RGB(0.58, 0.84, 0.66), RGB(0.42, 0.72, 0.52))
    hill(groundY - 36, 16, 1.4, 2.4, RGB(0.42, 0.78, 0.42), RGB(0.28, 0.62, 0.34))

    // drifting pollen / fireflies
    for k in 0..<14 {
        let sp = 8 + Double(k % 5) * 3
        let x = (Double(k) * 73 + time * sp).truncatingRemainder(dividingBy: Double(size.width) + 40) - 20
        let y = Double(groundY) * (0.25 + 0.7 * ((Double(k) * 0.381).truncatingRemainder(dividingBy: 1))) + sin(time * 0.8 + Double(k)) * 8
        let a = (0.35 + 0.35 * sin(time * 1.3 + Double(k) * 1.7)) * (1 - w * 0.7)
        ctx.fill(Path(ellipseIn: CGRect(x: x - 2, y: y - 2, width: 4, height: 4)), with: .color(Color(red: 1, green: 0.95, blue: 0.6).opacity(a)))
    }
}

struct SceneryBackground: View {
    var body: some View {
        TimelineView(.animation) { tl in
            let t = tl.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                drawScenery(&ctx, size: size, groundY: size.height * 0.52, wilt: 0, time: t)
                let r = CGRect(x: 0, y: size.height * 0.52, width: size.width, height: size.height * 0.48 + 2)
                ctx.fill(Path(r), with: .linearGradient(Gradient(colors: [RGB(0.28, 0.62, 0.34).color, RGB(0.16, 0.42, 0.26).color]),
                                                        startPoint: CGPoint(x: 0, y: r.minY), endPoint: CGPoint(x: 0, y: r.maxY)))
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: - Renderer

enum GameRenderer {
    static func draw(_ ctx: inout GraphicsContext, size: CGSize, engine e: GameEngine, time: Double) {
        if e.layout.size != size { e.layout.size = size }
        let L = e.layout
        let w = e.displayWilt
        let t = e.songTime
        let wallNow = CACurrentMediaTime()

        drawScenery(&ctx, size: size, groundY: L.highwayTop, wilt: w, time: time)

        // plant
        let pop = exp(-(wallNow - e.stageChangeTime) * 3.5)
        drawPlant(ctx, rect: L.plantRect.insetBy(dx: 0, dy: 4), health: e.displayHealth, wilt: w, time: time, pop: pop, flower: e.flower)

        // stage label (glass chip)
        let stageName = PlantStage.name(e.stage, flower: e.flower) + (w > 0.55 ? " · wilting" : "")
        let chip = CGRect(x: 14, y: L.plantRect.minY + 2, width: 14 + CGFloat(stageName.count) * 8.4, height: 26)
        ctx.fill(Path(roundedRect: chip, cornerRadius: 13), with: .color(.white.opacity(0.55)))
        ctx.stroke(Path(roundedRect: chip, cornerRadius: 13), with: .color(.white.opacity(0.8)), lineWidth: 1)
        drawText(&ctx, stageName, at: CGPoint(x: chip.midX, y: chip.midY), size: 13,
                 color: RGB(0.10, 0.34, 0.20).color, shadow: false)

        // highway bed (garden at dusk)
        let hw = CGRect(x: 0, y: L.highwayTop, width: size.width, height: size.height - L.highwayTop)
        ctx.fill(Path(hw), with: .linearGradient(
            Gradient(colors: [RGB(0.17, 0.38, 0.27).color, RGB(0.08, 0.20, 0.17).color, RGB(0.05, 0.12, 0.12).color]),
            startPoint: CGPoint(x: 0, y: hw.minY), endPoint: CGPoint(x: 0, y: hw.maxY)))
        ctx.fill(Path(CGRect(x: 0, y: hw.minY - 2, width: size.width, height: 6)),
                 with: .linearGradient(Gradient(colors: [RGB(0.58, 0.88, 0.46).color, RGB(0.30, 0.66, 0.34).color]),
                                       startPoint: CGPoint(x: 0, y: hw.minY - 2), endPoint: CGPoint(x: 0, y: hw.minY + 4)))

        // lanes (glass panels)
        for i in 0..<L.lanes {
            let c = Palette.laneColor(i, of: L.lanes)
            let r = CGRect(x: L.margin + L.laneW * CGFloat(i) + 3, y: hw.minY + 8, width: L.laneW - 6, height: hw.height - 8)
            ctx.fill(Path(roundedRect: r, cornerRadius: 14), with: .linearGradient(
                Gradient(colors: [c.color.opacity(0.03), c.color.opacity(0.20)]),
                startPoint: CGPoint(x: 0, y: r.minY), endPoint: CGPoint(x: 0, y: r.maxY)))
            ctx.stroke(Path(roundedRect: r, cornerRadius: 14), with: .color(.white.opacity(0.10)), lineWidth: 1)
            let glow = e.laneGlow[i]
            if glow > 0 {
                ctx.fill(Path(roundedRect: r, cornerRadius: 14),
                         with: .linearGradient(Gradient(colors: [c.color.opacity(0), c.color.opacity(0.5 * glow)]),
                                               startPoint: CGPoint(x: 0, y: r.minY), endPoint: CGPoint(x: 0, y: L.hitY + 30)))
            }
        }

        let travel = L.hitY - L.highwayTop
        func yFor(_ time: Double) -> CGFloat { L.hitY - CGFloat((time - t) / e.approach) * travel }

        var clipped = ctx
        clipped.clip(to: Path(CGRect(x: 0, y: hw.minY + 2, width: size.width, height: hw.height)))

        // scrolling beat lines (sense of tempo)
        if let song = e.currentSong {
            let beat = e.beatSec
            var k = max(0, Int(floor((t - song.leadIn) / beat)))
            while true {
                let bt = song.leadIn + Double(k) * beat
                if bt > t + e.approach { break }
                let y = yFor(bt)
                if y <= L.hitY + 20 {
                    var line = Path()
                    line.move(to: CGPoint(x: L.margin + 6, y: y)); line.addLine(to: CGPoint(x: size.width - L.margin - 6, y: y))
                    clipped.stroke(line, with: .color(.white.opacity(k % 4 == 0 ? 0.20 : 0.07)), lineWidth: k % 4 == 0 ? 2 : 1)
                }
                k += 1
            }
        }

        // notes
        let R = L.noteR
        for (idx, n) in e.notes.enumerated() {
            if n.time + n.dur < t - 0.6 { continue }
            if n.time > t + e.approach { break }
            if n.holdDone { continue }
            if n.hit && !n.holding && !n.holdFailed { continue }
            let x = L.laneX(n.lane)
            let col = Palette.laneColor(n.lane, of: L.lanes)
            let dim = (n.resolved && !n.hit) || n.holdFailed
            let headY = n.holding ? L.hitY : yFor(n.time)
            let alpha = dim ? 0.35 : min(1, Double(headY - L.highwayTop) / 40 + 0.2)

            // hold tail (vine)
            if n.isHold {
                let tailY = yFor(n.end)
                let top = min(tailY, headY), bot = headY
                if bot - top > 2 {
                    let tw = R * 0.78
                    let rect = CGRect(x: x - tw / 2, y: top, width: tw, height: bot - top)
                    let pulse = n.holding ? 0.75 + 0.25 * sin(time * 14) : 0.55
                    clipped.fill(Path(roundedRect: rect, cornerRadius: tw / 2),
                                 with: .linearGradient(Gradient(colors: [col.mixed(RGB(0, 0, 0), 0.2).color.opacity(alpha),
                                                                         col.mixed(RGB(1, 1, 1), 0.35).color.opacity(alpha),
                                                                         col.mixed(RGB(0, 0, 0), 0.2).color.opacity(alpha)]),
                                                       startPoint: CGPoint(x: rect.minX, y: 0), endPoint: CGPoint(x: rect.maxX, y: 0)))
                    clipped.stroke(Path(roundedRect: rect, cornerRadius: tw / 2), with: .color(.white.opacity(pulse * alpha)), lineWidth: 2)
                    var yy = bot - 26
                    var side = 1.0
                    while yy > top + 8 {
                        var lc = clipped
                        lc.translateBy(x: x + side * tw * 0.4, y: yy)
                        lc.rotate(by: .radians(side * 1.0))
                        var lp = Path()
                        lp.move(to: .zero)
                        lp.addQuadCurve(to: CGPoint(x: 0, y: -13), control: CGPoint(x: 7, y: -5))
                        lp.addQuadCurve(to: .zero, control: CGPoint(x: -7, y: -5))
                        lc.fill(lp, with: .color(RGB(0.42, 0.85, 0.40).color.opacity(alpha * 0.9)))
                        side = -side
                        yy -= 28
                    }
                    if tailY > L.highwayTop - 10 {
                        clipped.fill(Path(ellipseIn: CGRect(x: x - tw * 0.62, y: tailY - tw * 0.62, width: tw * 1.24, height: tw * 1.24)),
                                     with: .radialGradient(Gradient(colors: [col.mixed(RGB(1, 1, 1), 0.7).color.opacity(alpha), col.color.opacity(alpha)]),
                                                           center: CGPoint(x: x - 3, y: tailY - 3), startRadius: 1, endRadius: tw))
                    }
                    if n.holding {
                        clipped.fill(Path(ellipseIn: CGRect(x: x - R * 1.7, y: L.hitY - R * 1.7, width: R * 3.4, height: R * 3.4)),
                                     with: .radialGradient(Gradient(colors: [col.color.opacity(0.55), .clear]),
                                                           center: CGPoint(x: x, y: L.hitY), startRadius: 4, endRadius: R * 1.7))
                    }
                }
            }
            drawSeed(&clipped, at: CGPoint(x: x, y: headY), r: R, color: dim ? RGB(0.5, 0.5, 0.5) : col, alpha: alpha, hold: n.isHold)
        }

        // receptors (little flower pots)
        for i in 0..<L.lanes {
            let c = Palette.laneColor(i, of: L.lanes)
            let x = L.laneX(i)
            let glow = e.laneGlow[i]
            let rr = R + 6 + CGFloat(glow) * 3
            let ring = CGRect(x: x - rr, y: L.hitY - rr, width: rr * 2, height: rr * 2)
            ctx.fill(Path(ellipseIn: ring.offsetBy(dx: 0, dy: 4)), with: .color(.black.opacity(0.3)))
            ctx.fill(Path(ellipseIn: ring), with: .radialGradient(
                Gradient(colors: [c.mixed(RGB(0.2, 0.12, 0.08), 0.75).color, RGB(0.22, 0.13, 0.08).color]),
                center: CGPoint(x: x, y: L.hitY - 4), startRadius: 2, endRadius: rr))
            ctx.fill(Path(ellipseIn: ring.insetBy(dx: 5, dy: 5)), with: .color(c.color.opacity(0.10 + 0.6 * glow)))
            ctx.stroke(Path(ellipseIn: ring), with: .linearGradient(
                Gradient(colors: [c.mixed(RGB(1, 1, 1), 0.5).color, c.color, c.mixed(RGB(0, 0, 0), 0.25).color]),
                startPoint: CGPoint(x: x, y: ring.minY), endPoint: CGPoint(x: x, y: ring.maxY)), lineWidth: 5)
            var sp = ctx
            sp.translateBy(x: x, y: L.hitY + 6)
            var stemP = Path()
            stemP.move(to: .zero); stemP.addLine(to: CGPoint(x: 0, y: -10))
            sp.stroke(stemP, with: .color(RGB(0.5, 0.9, 0.45).color.opacity(0.7)), lineWidth: 2)
            for sd in [-1.0, 1.0] {
                var l = sp
                l.translateBy(x: 0, y: -10)
                l.rotate(by: .radians(sd * 0.9))
                l.fill(Path(ellipseIn: CGRect(x: -3, y: -10, width: 6, height: 10)), with: .color(RGB(0.5, 0.9, 0.45).color.opacity(0.75)))
            }
        }

        // particles
        for p in e.particles {
            let a = max(0, p.life / p.maxLife)
            var pc = ctx
            pc.translateBy(x: p.x, y: p.y)
            pc.rotate(by: .radians(p.rot))
            if p.sparkle {
                var star = Path()
                let s = p.size * (0.6 + 0.4 * a)
                star.move(to: CGPoint(x: 0, y: -s)); star.addLine(to: CGPoint(x: s * 0.28, y: -s * 0.28))
                star.addLine(to: CGPoint(x: s, y: 0)); star.addLine(to: CGPoint(x: s * 0.28, y: s * 0.28))
                star.addLine(to: CGPoint(x: 0, y: s)); star.addLine(to: CGPoint(x: -s * 0.28, y: s * 0.28))
                star.addLine(to: CGPoint(x: -s, y: 0)); star.addLine(to: CGPoint(x: -s * 0.28, y: -s * 0.28))
                star.closeSubpath()
                pc.fill(star, with: .color(p.color.color.opacity(a)))
            } else {
                pc.fill(Path(ellipseIn: CGRect(x: -p.size / 2, y: -p.size / 3, width: p.size, height: p.size * 0.66)),
                        with: .linearGradient(Gradient(colors: [p.color.mixed(RGB(1, 1, 1), 0.5).color.opacity(a), p.color.color.opacity(a)]),
                                              startPoint: CGPoint(x: 0, y: -p.size / 3), endPoint: CGPoint(x: 0, y: p.size / 3)))
            }
        }

        // HUD: score pill
        let pill = CGRect(x: 14, y: L.topInset + 4, width: 150, height: 40)
        ctx.fill(Path(roundedRect: pill, cornerRadius: 20), with: .color(.black.opacity(0.26)))
        ctx.stroke(Path(roundedRect: pill, cornerRadius: 20), with: .color(.white.opacity(0.35)), lineWidth: 1)
        drawText(&ctx, "\(e.score)", at: CGPoint(x: pill.minX + 18, y: pill.midY), size: 24, color: .white,
                 anchor: .leading, shadow: false, mono: true)

        // HUD: growth bar
        let bar = CGRect(x: 14, y: L.topInset + 54, width: size.width - 28, height: 12)
        ctx.fill(Path(roundedRect: bar, cornerRadius: 6), with: .color(.black.opacity(0.28)))
        let fillW = max(12, bar.width * CGFloat(e.displayHealth))
        let fr = CGRect(x: bar.minX, y: bar.minY, width: fillW, height: bar.height)
        ctx.fill(Path(roundedRect: fr, cornerRadius: 6),
                 with: .linearGradient(Gradient(colors: [RGB(0.45, 0.85, 0.35).color, RGB(1.0, 0.85, 0.35).color, RGB(1.0, 0.55, 0.72).color]),
                                       startPoint: CGPoint(x: bar.minX, y: 0), endPoint: CGPoint(x: bar.maxX, y: 0)))
        ctx.fill(Path(roundedRect: CGRect(x: fr.minX + 3, y: fr.minY + 2, width: max(0, fr.width - 6), height: 3), cornerRadius: 1.5),
                 with: .color(.white.opacity(0.45)))
        for th in PlantStage.thresholds.dropFirst() {
            let x = bar.minX + bar.width * CGFloat(th)
            ctx.fill(Path(ellipseIn: CGRect(x: x - 3, y: bar.midY - 3, width: 6, height: 6)),
                     with: .color(.white.opacity(e.displayHealth >= th ? 0.95 : 0.55)))
        }
        ctx.stroke(Path(roundedRect: bar, cornerRadius: 6), with: .color(.white.opacity(0.5)), lineWidth: 1)

        // combo
        if e.combo >= 3 {
            drawText(&ctx, "\(e.combo)", at: CGPoint(x: size.width / 2, y: L.highwayTop + 54), size: 56,
                     color: .white.opacity(0.9))
            drawText(&ctx, "COMBO", at: CGPoint(x: size.width / 2, y: L.highwayTop + 92), size: 13,
                     color: .white.opacity(0.75))
        }

        // judgment
        let jt = wallNow - e.lastJudgmentTime
        if jt < 0.6 {
            let a = 1 - smooth(0.3, 0.6, jt)
            let pp = 1 + 0.25 * exp(-jt * 14)
            var jc = ctx
            jc.translateBy(x: size.width / 2, y: L.hitY - 110 - CGFloat(jt) * 24)
            jc.scaleBy(x: pp, y: pp)
            drawText(&jc, e.lastJudgment.label, at: .zero, size: 32, color: e.lastJudgment.color.color.opacity(a))
        }

        // intro hint
        if t < 2.2 {
            let a = 1 - smooth(1.6, 2.2, t)
            drawText(&ctx, "Tap seeds as they reach the pots", at: CGPoint(x: size.width / 2, y: (L.highwayTop + L.hitY) / 2 - 14),
                     size: 18, color: .white.opacity(a))
            drawText(&ctx, "Hold the vines · tap matching seeds together", at: CGPoint(x: size.width / 2, y: (L.highwayTop + L.hitY) / 2 + 14),
                     size: 14, color: .white.opacity(a * 0.85), weight: .bold)
        }
    }

    static func drawSeed(_ ctx: inout GraphicsContext, at p: CGPoint, r: CGFloat, color: RGB, alpha: Double, hold: Bool) {
        var g = ctx
        g.translateBy(x: p.x, y: p.y)
        g.fill(Path(ellipseIn: CGRect(x: -r * 0.95, y: -r * 0.8, width: r * 1.9, height: r * 1.9)), with: .color(.black.opacity(0.28 * alpha)))
        let body = CGRect(x: -r, y: -r, width: r * 2, height: r * 2)
        g.fill(Path(ellipseIn: body), with: .radialGradient(
            Gradient(colors: [color.mixed(RGB(1, 1, 1), 0.65).color.opacity(alpha), color.color.opacity(alpha),
                              color.mixed(RGB(0, 0, 0), 0.38).color.opacity(alpha)]),
            center: CGPoint(x: -r * 0.32, y: -r * 0.38), startRadius: 1, endRadius: r * 1.45))
        g.stroke(Path(ellipseIn: body), with: .color(.white.opacity(0.9 * alpha)), lineWidth: hold ? 3.5 : 2.5)
        g.fill(Path(ellipseIn: CGRect(x: -r * 0.62, y: -r * 0.70, width: r * 0.62, height: r * 0.36)), with: .color(.white.opacity(0.55 * alpha)))
        if hold {
            g.stroke(Path(ellipseIn: body.insetBy(dx: r * 0.28, dy: r * 0.28)), with: .color(.white.opacity(0.55 * alpha)), lineWidth: 2)
        }
        var leaf = g
        leaf.translateBy(x: 0, y: -r * 0.88)
        for sd in [-1.0, 1.0] {
            var l = leaf
            l.rotate(by: .radians(sd * 0.7))
            var path = Path()
            path.move(to: .zero)
            path.addQuadCurve(to: CGPoint(x: 0, y: -r * 0.72), control: CGPoint(x: r * 0.38, y: -r * 0.3))
            path.addQuadCurve(to: .zero, control: CGPoint(x: -r * 0.38, y: -r * 0.3))
            l.fill(path, with: .linearGradient(Gradient(colors: [RGB(0.55, 0.92, 0.45).color.opacity(alpha), RGB(0.22, 0.62, 0.28).color.opacity(alpha)]),
                                               startPoint: CGPoint(x: 0, y: -r * 0.7), endPoint: .zero))
        }
    }
}
