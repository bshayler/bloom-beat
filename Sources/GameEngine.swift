import SwiftUI
import AVFoundation
import UIKit

enum Phase { case menu, loading, playing, paused, finished, shelf }

struct Particle {
    var x: Double, y: Double, vx: Double, vy: Double
    var life: Double, maxLife: Double
    var color: RGB
    var size: Double
    var rot: Double, spin: Double
    var sparkle: Bool
}

struct Layout {
    var size = CGSize(width: 390, height: 844)
    var topInset: CGFloat = 47
    var bottomInset: CGFloat = 34
    var lanes = 3
    var margin: CGFloat { 10 }
    var laneW: CGFloat { (size.width - 2 * margin) / CGFloat(lanes) }
    var plantRect: CGRect { CGRect(x: 0, y: topInset + 64, width: size.width, height: size.height * 0.30) }
    var highwayTop: CGFloat { plantRect.maxY }
    var hitY: CGFloat { size.height - bottomInset - 74 }
    var noteR: CGFloat { min(laneW * 0.34, 30) }
    func laneX(_ i: Int) -> CGFloat { margin + laneW * (CGFloat(i) + 0.5) }
    func lane(atX x: CGFloat) -> Int { min(lanes - 1, max(0, Int(floor((x - margin) / laneW)))) }
}

final class GameEngine: NSObject, ObservableObject {
    @Published var phase: Phase = .menu
    @Published var selectedSong = 0
    @Published var difficulty: Difficulty = .three
    @Published var shelf: [PlantRecord] = []
    static let shelfKey = "shelf.v1"

    override init() {
        super.init()
        if let data = UserDefaults.standard.data(forKey: GameEngine.shelfKey),
           let recs = try? JSONDecoder().decode([PlantRecord].self, from: data) {
            shelf = recs
        }
        if ProcessInfo.processInfo.arguments.contains("-seedshelf") && shelf.isEmpty {
            let ids = SongSpec.all.map { $0.id }
            let samples: [(Double, Double, Int, String)] = [(0.97, 0, 98200, "S"), (0.85, 0, 61400, "A"), (0.72, 0, 40100, "B"),
                                                           (0.58, 0, 25300, "C"), (0.40, 0, 14100, "C"), (0.05, 0.9, 3200, "D"), (0.30, 0.8, 5100, "D")]
            for (i, x) in samples.enumerated() {
                shelf.append(PlantRecord(songID: ids[i % ids.count], lanes: 2 + i % 4, health: x.0, wilt: x.1, score: x.2,
                                         grade: x.3, maxCombo: 20 + i * 11, date: Date().addingTimeInterval(Double(-i) * 3600)))
            }
        }
    }

    func saveShelf() {
        if let data = try? JSONEncoder().encode(shelf) { UserDefaults.standard.set(data, forKey: GameEngine.shelfKey) }
    }

    func removeFromShelf(_ r: PlantRecord) {
        shelf.removeAll { $0.id == r.id }
        saveShelf()
    }

    let songs = SongSpec.all
    var cache: [String: RenderedSong] = [:]

    // Layout
    var layout = Layout()

    // Play state
    var notes: [GNote] = []
    var firstActive = 0
    var songTime = 0.0
    var duration = 0.0
    var lanes = 3
    var approach = 1.9
    var score = 0
    var combo = 0
    var maxCombo = 0
    var counts = [0, 0, 0, 0]
    var health = 0.15
    var displayHealth = 0.15
    var displayWilt = 0.0
    var recentMiss = 0.0
    var gain = 0.02
    var lastJudgment: Judgment = .perfect
    var lastJudgmentTime = -10.0
    var laneGlow = [Double](repeating: 0, count: 5)
    var particles: [Particle] = []
    var lastStage = 0
    var stageChangeTime = -10.0
    var currentSong: RenderedSong?
    var beatSec = 0.5
    var activeHolds: [Int] = []
    var touchHolds: [ObjectIdentifier: Int] = [:]

    // Audio / clock
    var player: AVAudioPlayer?
    var link: CADisplayLink?
    var lastA = 0.0
    var lastHost = 0.0
    var lastFrame = 0.0
    var outputLatency = 0.0
    let haptic = UIImpactFeedbackGenerator(style: .light)

    let autoplay = ProcessInfo.processInfo.arguments.contains("-autoplay")
    let perfectWin = 0.055, greatWin = 0.10, goodWin = 0.15

    var totalNotes: Int { notes.count }
    var stage: Int { PlantStage.index(for: displayHealth) }

    var accuracy: Double {
        guard totalNotes > 0 else { return 0 }
        return (Double(counts[0]) + 0.8 * Double(counts[1]) + 0.5 * Double(counts[2])) / Double(totalNotes)
    }
    var grade: String {
        switch accuracy {
        case 0.95...: return "S"
        case 0.88...: return "A"
        case 0.75...: return "B"
        case 0.60...: return "C"
        default: return "D"
        }
    }

    // MARK: Layout

    func setLayout(size: CGSize, top: CGFloat, bottom: CGFloat) {
        layout.size = size
        layout.topInset = top
        layout.bottomInset = bottom
    }

    // MARK: Start / stop

    func bestKey(_ song: SongSpec, _ lanes: Int) -> String { "best.\(song.id).\(lanes)" }
    func best(_ song: SongSpec, _ lanes: Int) -> Int { UserDefaults.standard.integer(forKey: bestKey(song, lanes)) }

    func start() {
        guard phase == .menu || phase == .finished else { return }
        phase = .loading
        let spec = songs[selectedSong]
        let diff = difficulty
        if let cached = cache[spec.id] {
            begin(cached, diff)
            return
        }
        Task {
            let rendered = await Task.detached(priority: .userInitiated) { SongRenderer.render(spec) }.value
            await MainActor.run {
                self.cache[spec.id] = rendered
                self.begin(rendered, diff)
            }
        }
    }

    func begin(_ r: RenderedSong, _ diff: Difficulty) {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)
            outputLatency = max(0, min(0.25, session.outputLatency))
            let p = try AVAudioPlayer(data: r.wav)
            p.prepareToPlay()
            player = p
        } catch {
            phase = .menu
            return
        }
        currentSong = r
        beatSec = 60 / r.spec.bpm
        activeHolds = []
        touchHolds = [:]
        lanes = diff.lanes
        approach = diff.approach
        layout.lanes = lanes
        notes = ChartBuilder.build(song: r, lanes: lanes)
        firstActive = 0
        duration = r.duration
        score = 0; combo = 0; maxCombo = 0
        counts = [0, 0, 0, 0]
        health = 0.15; displayHealth = 0.15; displayWilt = 0; recentMiss = 0
        gain = 1.3 / Double(max(1, notes.count))
        lastJudgmentTime = -10
        particles = []
        laneGlow = [Double](repeating: 0, count: 5)
        lastStage = 0
        stageChangeTime = -10
        songTime = 0
        lastA = 0
        lastHost = CACurrentMediaTime()
        lastFrame = lastHost
        haptic.prepare()
        player?.play()
        phase = .playing
        link?.invalidate()
        let l = CADisplayLink(target: self, selector: #selector(step))
        l.add(to: .main, forMode: .common)
        link = l
    }

    func pause() {
        guard phase == .playing else { return }
        player?.pause()
        phase = .paused
    }

    func resume() {
        guard phase == .paused else { return }
        let now = CACurrentMediaTime()
        lastHost = now
        lastFrame = now
        player?.play()
        phase = .playing
    }

    func quit() {
        link?.invalidate(); link = nil
        player?.stop(); player = nil
        phase = .menu
    }

    func finish() {
        link?.invalidate(); link = nil
        player?.stop(); player = nil
        if let s = currentSong {
            let key = bestKey(s.spec, lanes)
            if score > UserDefaults.standard.integer(forKey: key) {
                UserDefaults.standard.set(score, forKey: key)
            }
        }
        if let s = currentSong {
            shelf.insert(PlantRecord(songID: s.spec.id, lanes: lanes, health: health, wilt: displayWilt,
                                     score: score, grade: grade, maxCombo: maxCombo, date: Date()), at: 0)
            if shelf.count > 90 { shelf.removeLast(shelf.count - 90) }
            saveShelf()
        }
        phase = .finished
    }

    // MARK: Frame loop

    @objc func step() {
        guard phase == .playing, let p = player else { return }
        let now = CACurrentMediaTime()
        let a = p.currentTime
        if a != lastA { lastA = a; lastHost = now }
        songTime = lastA + (now - lastHost) - outputLatency
        let dt = min(0.05, now - lastFrame)
        lastFrame = now

        // debug: `-autoplay` launch argument hits every note perfectly
        if autoplay {
            var k = firstActive
            while k < notes.count && notes[k].time <= songTime {
                if !notes[k].resolved { registerHit(k, .perfect) }
                k += 1
            }
        }

        // expire missed notes
        var i = firstActive
        while i < notes.count && notes[i].time < songTime - goodWin {
            if !notes[i].resolved { registerMiss(i) }
            i += 1
        }
        while firstActive < notes.count && notes[firstActive].resolved && notes[firstActive].time < songTime - 0.5 {
            firstActive += 1
        }

        // holds: finish when their tail reaches the pot
        for idx in activeHolds where notes[idx].holding && songTime >= notes[idx].end - 0.03 {
            completeHold(idx)
        }
        activeHolds.removeAll { !notes[$0].holding }
        for idx in activeHolds {
            laneGlow[notes[idx].lane] = 1
            if Double.random(in: 0...1) < 0.5 { holdSpark(lane: notes[idx].lane) }
        }

        updateVisuals(dt: dt, now: now)

        if (!p.isPlaying && songTime > 1) || songTime > duration - 0.2 {
            finish()
        }
    }

    func updateVisuals(dt: Double, now: Double) {
        displayHealth += (health - displayHealth) * min(1, dt * 3)
        recentMiss = max(0, recentMiss - dt * 0.35)
        let lowWilt = max(0, (0.08 - health) / 0.08)
        let target = min(1, recentMiss + lowWilt)
        displayWilt += (target - displayWilt) * min(1, dt * 4)
        for k in 0..<laneGlow.count { laneGlow[k] = max(0, laneGlow[k] - dt * 5) }

        let st = stage
        if st > lastStage {
            stageChangeTime = now
            sparkle(around: CGPoint(x: layout.plantRect.midX, y: layout.plantRect.midY))
        }
        lastStage = st

        for k in particles.indices {
            particles[k].life -= dt
            particles[k].x += particles[k].vx * dt
            particles[k].y += particles[k].vy * dt
            particles[k].vy += (particles[k].sparkle ? 0 : 260) * dt
            particles[k].rot += particles[k].spin * dt
        }
        particles.removeAll { $0.life <= 0 }
    }

    // MARK: Input

    func touchBegan(id: ObjectIdentifier, at p: CGPoint, timestamp: TimeInterval) {
        guard phase == .playing, p.y > layout.highwayTop - 30 else { return }
        let idx = tap(lane: layout.lane(atX: p.x), host: timestamp)
        if idx >= 0, notes[idx].isHold { touchHolds[id] = idx }
    }

    func touchEnded(id: ObjectIdentifier, timestamp: TimeInterval) {
        guard let idx = touchHolds.removeValue(forKey: id), notes[idx].holding else { return }
        let h = min(timestamp, CACurrentMediaTime())
        let t = lastA + (h - lastHost) - outputLatency
        if t >= notes[idx].end - 0.2 { completeHold(idx) } else { failHold(idx) }
    }

    @discardableResult
    func tap(lane: Int, host: Double) -> Int {
        guard phase == .playing else { return -1 }
        laneGlow[lane] = 1
        let h = min(host, CACurrentMediaTime())
        let t = lastA + (h - lastHost) - outputLatency
        var best = -1
        var bestD = goodWin + 0.0001
        var i = firstActive
        while i < notes.count && notes[i].time < t + goodWin {
            if !notes[i].resolved && notes[i].lane == lane {
                let d = abs(notes[i].time - t)
                if d < bestD { bestD = d; best = i }
            }
            i += 1
        }
        guard best >= 0 else { return -1 }
        let j: Judgment = bestD <= perfectWin ? .perfect : (bestD <= greatWin ? .great : .good)
        registerHit(best, j)
        return best
    }

    func registerHit(_ i: Int, _ j: Judgment) {
        notes[i].resolved = true
        notes[i].hit = true
        if notes[i].isHold {
            notes[i].holding = true
            activeHolds.append(i)
        }
        combo += 1
        maxCombo = max(maxCombo, combo)
        counts[j.rawValue] += 1
        let base: Int = j == .perfect ? 300 : (j == .great ? 200 : 100)
        let mult = 1.0 + Double(min(combo, 40)) / 20.0
        score += Int(Double(base) * mult)
        let g: Double = j == .perfect ? 1 : (j == .great ? 0.75 : 0.5)
        health = min(1, health + gain * g)
        lastJudgment = j
        lastJudgmentTime = CACurrentMediaTime()
        burst(lane: notes[i].lane, color: Palette.laneColor(notes[i].lane, of: lanes), big: j == .perfect)
        haptic.impactOccurred()
    }

    func completeHold(_ i: Int) {
        notes[i].holding = false
        notes[i].holdDone = true
        score += Int(150 * (1.0 + Double(min(combo, 40)) / 20.0))
        health = min(1, health + gain * 0.5)
        burst(lane: notes[i].lane, color: Palette.laneColor(notes[i].lane, of: lanes), big: true)
    }

    func failHold(_ i: Int) {
        notes[i].holding = false
        notes[i].holdFailed = true
        combo = 0
        health = max(0, health - gain)
        recentMiss = min(1, recentMiss + 0.25)
        lastJudgment = .miss
        lastJudgmentTime = CACurrentMediaTime()
    }

    func holdSpark(lane: Int) {
        let c = Palette.laneColor(lane, of: lanes).mixed(RGB(1, 1, 1), 0.5)
        particles.append(Particle(x: Double(layout.laneX(lane)) + Double.random(in: -14...14), y: Double(layout.hitY),
                                  vx: Double.random(in: -20...20), vy: Double.random(in: -150 ... -60),
                                  life: 0.5, maxLife: 0.5, color: c, size: Double.random(in: 4...8),
                                  rot: 0, spin: 4, sparkle: true))
    }

    func registerMiss(_ i: Int) {
        notes[i].resolved = true
        combo = 0
        counts[3] += 1
        health = max(0, health - gain * 2)
        recentMiss = min(1, recentMiss + 0.3)
        lastJudgment = .miss
        lastJudgmentTime = CACurrentMediaTime()
    }

    // MARK: Particles

    func burst(lane: Int, color: RGB, big: Bool) {
        let cx = Double(layout.laneX(lane)), cy = Double(layout.hitY)
        let n = big ? 12 : 8
        for _ in 0..<n {
            let a = Double.random(in: 0..<(2 * .pi))
            let sp = Double.random(in: 60...220)
            particles.append(Particle(x: cx, y: cy, vx: cos(a) * sp, vy: sin(a) * sp - 120,
                                      life: Double.random(in: 0.5...0.9), maxLife: 0.9,
                                      color: color.mixed(RGB(1, 1, 1), Double.random(in: 0...0.4)),
                                      size: Double.random(in: 8...14), rot: Double.random(in: 0..<6.28),
                                      spin: Double.random(in: -8...8), sparkle: false))
        }
        if particles.count > 250 { particles.removeFirst(particles.count - 250) }
    }

    func sparkle(around c: CGPoint) {
        for _ in 0..<22 {
            let a = Double.random(in: 0..<(2 * .pi))
            let sp = Double.random(in: 40...150)
            particles.append(Particle(x: Double(c.x), y: Double(c.y), vx: cos(a) * sp, vy: sin(a) * sp,
                                      life: Double.random(in: 0.7...1.2), maxLife: 1.2,
                                      color: RGB(1, 0.92, 0.45), size: Double.random(in: 6...12),
                                      rot: 0, spin: 3, sparkle: true))
        }
    }
}
