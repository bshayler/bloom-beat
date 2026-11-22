import Foundation

// MARK: - Song definitions (all music is original and synthesized in-app => royalty free)

struct Chord { let root: Int; let intervals: [Int] }

struct SongSpec: Identifiable {
    let id: String
    let title: String
    let blurb: String
    let emoji: String
    let bpm: Double
    let root: Int            // midi tonic of the melody scale
    let seed: UInt64
    let chords: [Chord]
    let maxRhythm: Int       // how busy the rhythm templates may get
    let kickBeats: [Double]
    let hatStep: Double
    var kind: Kind = .generated
    var leadDecay: Double = 3.2
    var tune = ""
    var group = "Originals"
    var scale: [Int] = [0, 2, 4, 7, 9]   // five-note scale used by generated melodies
    var leadTable = 0                      // 0 bell/pluck, 1 buzzy saw
    var snare = false
    var arp = false
    var sustain = false                    // long held notes on the third bar of each phrase

    enum Kind { case generated, mountainKing, bumblebee, tune }

    static let majT = [0, 4, 7]
    static let minT = [0, 3, 7]

    static let all: [SongSpec] = [
        SongSpec(id: "dew", title: "Morning Dew", blurb: "Gentle and slow", emoji: "🌱",
                 bpm: 92, root: 60, seed: 11,
                 chords: [Chord(root: 0, intervals: majT), Chord(root: 9, intervals: minT),
                          Chord(root: 5, intervals: majT), Chord(root: 7, intervals: majT)],
                 maxRhythm: 4, kickBeats: [0, 2], hatStep: 1),
        SongSpec(id: "sun", title: "Sunbeam Stroll", blurb: "Bright and bouncy", emoji: "🌻",
                 bpm: 112, root: 55, seed: 23,
                 chords: [Chord(root: 0, intervals: majT), Chord(root: 7, intervals: majT),
                          Chord(root: 9, intervals: minT), Chord(root: 5, intervals: majT)],
                 maxRhythm: 6, kickBeats: [0, 1.5, 2], hatStep: 0.5),
        SongSpec(id: "rain", title: "Rain Dance", blurb: "Fast and sparkly", emoji: "🌧️",
                 bpm: 128, root: 62, seed: 37,
                 chords: [Chord(root: 9, intervals: minT), Chord(root: 5, intervals: majT),
                          Chord(root: 0, intervals: majT), Chord(root: 7, intervals: majT)],
                 maxRhythm: 7, kickBeats: [0, 1, 2, 3], hatStep: 0.5),
        SongSpec(id: "king", title: "In the Hall of the Mountain King", blurb: "Grieg, 1875 · public domain", emoji: "⛰️",
                 bpm: 120, root: 59,  seed: 0,
                 chords: [Chord(root: 0, intervals: minT), Chord(root: 0, intervals: minT),
                          Chord(root: 7, intervals: majT), Chord(root: 0, intervals: minT)],
                 maxRhythm: 7, kickBeats: [0, 2], hatStep: 1, kind: .mountainKing, leadDecay: 5, group: "Classical"),
        SongSpec(id: "bee", title: "Flight of the Bumblebee", blurb: "Rimsky-Korsakov, 1900 · public domain", emoji: "🐝",
                 bpm: 138, root: 57, seed: 0,
                 chords: [Chord(root: 0, intervals: minT), Chord(root: 7, intervals: majT),
                          Chord(root: 0, intervals: minT), Chord(root: 5, intervals: minT)],
                 maxRhythm: 7, kickBeats: [0, 2], hatStep: 0.5, kind: .bumblebee, leadDecay: 7, group: "Classical"),
        SongSpec(id: "ode", title: "Ode to Joy", blurb: "Beethoven, 1824 · public domain", emoji: "🎻",
                 bpm: 108, root: 60,  seed: 0,
                 chords: [Chord(root: 0, intervals: majT), Chord(root: 7, intervals: majT),
                          Chord(root: 0, intervals: majT), Chord(root: 5, intervals: majT)],
                 maxRhythm: 4, kickBeats: [0, 2], hatStep: 1, kind: .tune, leadDecay: 3,
                 tune: SongSpec.odeToJoy, group: "Classical"),
        SongSpec(id: "twinkle", title: "Twinkle Twinkle Little Star", blurb: "Traditional · public domain", emoji: "⭐",
                 bpm: 100, root: 60, seed: 0,
                 chords: [Chord(root: 0, intervals: majT), Chord(root: 5, intervals: majT),
                          Chord(root: 0, intervals: majT), Chord(root: 7, intervals: majT)],
                 maxRhythm: 4, kickBeats: [0, 2], hatStep: 1, kind: .tune, leadDecay: 3,
                 tune: SongSpec.twinkle, group: "Folk & nursery"),
        SongSpec(id: "jingle", title: "Jingle Bells", blurb: "Pierpont, 1857 · public domain", emoji: "🔔",
                 bpm: 120, root: 60, seed: 0,
                 chords: [Chord(root: 0, intervals: majT), Chord(root: 5, intervals: majT),
                          Chord(root: 0, intervals: majT), Chord(root: 7, intervals: majT)],
                 maxRhythm: 5, kickBeats: [0, 2], hatStep: 0.5, kind: .tune, leadDecay: 4,
                 tune: SongSpec.jingleBells, group: "Folk & nursery"),
        SongSpec(id: "saints", title: "When the Saints Go Marching In", blurb: "Traditional · public domain", emoji: "🎺",
                 bpm: 132, root: 60, seed: 0,
                 chords: [Chord(root: 0, intervals: majT), Chord(root: 0, intervals: majT),
                          Chord(root: 5, intervals: majT), Chord(root: 7, intervals: majT)],
                 maxRhythm: 6, kickBeats: [0, 1.5, 2], hatStep: 0.5, kind: .tune, leadDecay: 4,
                 tune: SongSpec.saints, group: "Folk & nursery"),
        SongSpec(id: "mary", title: "Mary Had a Little Lamb", blurb: "Traditional · public domain", emoji: "🐑",
                 bpm: 104, root: 60, seed: 0,
                 chords: [Chord(root: 0, intervals: majT), Chord(root: 7, intervals: majT),
                          Chord(root: 0, intervals: majT), Chord(root: 5, intervals: majT)],
                 maxRhythm: 4, kickBeats: [0, 2], hatStep: 1, kind: .tune, leadDecay: 3,
                 tune: SongSpec.mary, group: "Folk & nursery"),
        SongSpec(id: "moon", title: "Moonlit Meadow", blurb: "Dreamy and slow", emoji: "🌙",
                 bpm: 84, root: 62, seed: 51,
                 chords: [Chord(root: 0, intervals: majT), Chord(root: 9, intervals: minT),
                          Chord(root: 5, intervals: majT), Chord(root: 7, intervals: majT)],
                 maxRhythm: 3, kickBeats: [0], hatStep: 1, leadDecay: 2.2, sustain: true),
        SongSpec(id: "firefly", title: "Firefly Rush", blurb: "Quick and twinkly", emoji: "✨",
                 bpm: 148, root: 64, seed: 63,
                 chords: [Chord(root: 9, intervals: minT), Chord(root: 5, intervals: majT),
                          Chord(root: 0, intervals: majT), Chord(root: 7, intervals: majT)],
                 maxRhythm: 7, kickBeats: [0, 1, 2, 3], hatStep: 0.5, leadDecay: 5),
        SongSpec(id: "petal", title: "Petal Storm", blurb: "Expert · very fast", emoji: "🌸",
                 bpm: 168, root: 59, seed: 77,
                 chords: [Chord(root: 0, intervals: majT), Chord(root: 7, intervals: majT),
                          Chord(root: 9, intervals: minT), Chord(root: 5, intervals: majT)],
                 maxRhythm: 7, kickBeats: [0, 1, 2, 3], hatStep: 0.5, leadDecay: 6),
        SongSpec(id: "row", title: "Row, Row, Row Your Boat", blurb: "Traditional · public domain", emoji: "🚣",
                 bpm: 108, root: 60, seed: 0,
                 chords: [Chord(root: 0, intervals: majT), Chord(root: 0, intervals: majT),
                          Chord(root: 5, intervals: majT), Chord(root: 7, intervals: majT)],
                 maxRhythm: 4, kickBeats: [0, 2], hatStep: 1, kind: .tune, leadDecay: 3,
                 tune: SongSpec.row, group: "Folk & nursery"),
        SongSpec(id: "buns", title: "Hot Cross Buns", blurb: "Traditional · public domain", emoji: "🥐",
                 bpm: 112, root: 60, seed: 0,
                 chords: [Chord(root: 0, intervals: majT), Chord(root: 7, intervals: majT),
                          Chord(root: 0, intervals: majT), Chord(root: 5, intervals: majT)],
                 maxRhythm: 4, kickBeats: [0, 2], hatStep: 1, kind: .tune, leadDecay: 3,
                 tune: SongSpec.buns, group: "Folk & nursery"),
        SongSpec(id: "london", title: "London Bridge Is Falling Down", blurb: "Traditional · public domain", emoji: "🌉",
                 bpm: 116, root: 67, seed: 0,
                 chords: [Chord(root: 0, intervals: majT), Chord(root: 7, intervals: majT),
                          Chord(root: 0, intervals: majT), Chord(root: 5, intervals: majT)],
                 maxRhythm: 4, kickBeats: [0, 2], hatStep: 1, kind: .tune, leadDecay: 3.5,
                 tune: SongSpec.london, group: "Folk & nursery"),
        SongSpec(id: "susanna", title: "Oh! Susanna", blurb: "Foster, 1848 · public domain", emoji: "🪕",
                 bpm: 124, root: 60, seed: 0,
                 chords: [Chord(root: 0, intervals: majT), Chord(root: 0, intervals: majT),
                          Chord(root: 7, intervals: majT), Chord(root: 0, intervals: majT)],
                 maxRhythm: 5, kickBeats: [0, 1.5, 2], hatStep: 0.5, kind: .tune, leadDecay: 4,
                 tune: SongSpec.susanna, group: "Folk & nursery"),
        SongSpec(id: "neon", title: "Neon Greenhouse", blurb: "Synthwave · minor", emoji: "🪴",
                 bpm: 118, root: 57, seed: 101,
                 chords: [Chord(root: 0, intervals: minT), Chord(root: 8, intervals: majT),
                          Chord(root: 3, intervals: majT), Chord(root: 10, intervals: majT)],
                 maxRhythm: 6, kickBeats: [0, 1, 2, 3], hatStep: 0.5, leadDecay: 4, group: "Cool originals",
                 scale: [0, 3, 5, 7, 10], leadTable: 1, snare: true, arp: true),
        SongSpec(id: "funk", title: "Venus Flytrap Funk", blurb: "Blues groove · syncopated", emoji: "🕺",
                 bpm: 102, root: 64, seed: 113,
                 chords: [Chord(root: 0, intervals: minT), Chord(root: 5, intervals: minT),
                          Chord(root: 0, intervals: minT), Chord(root: 7, intervals: majT)],
                 maxRhythm: 6, kickBeats: [0, 1.5, 2.5], hatStep: 0.5, leadDecay: 5, group: "Cool originals",
                 scale: [0, 3, 5, 6, 7], leadTable: 1, snare: true, sustain: true),
        SongSpec(id: "sakura", title: "Sakura Drift", blurb: "Serene · Japanese scale", emoji: "🏯",
                 bpm: 92, root: 62, seed: 127,
                 chords: [Chord(root: 0, intervals: minT), Chord(root: 8, intervals: majT),
                          Chord(root: 0, intervals: minT), Chord(root: 7, intervals: majT)],
                 maxRhythm: 4, kickBeats: [0], hatStep: 1, leadDecay: 2.6, group: "Cool originals",
                 scale: [0, 2, 3, 7, 8], arp: true, sustain: true),
        SongSpec(id: "thunder", title: "Thunder Bloom", blurb: "Electro · hard", emoji: "⚡",
                 bpm: 156, root: 59, seed: 139,
                 chords: [Chord(root: 0, intervals: minT), Chord(root: 8, intervals: majT),
                          Chord(root: 10, intervals: majT), Chord(root: 0, intervals: minT)],
                 maxRhythm: 7, kickBeats: [0, 1, 2, 3], hatStep: 0.5, leadDecay: 6, group: "Cool originals",
                 scale: [0, 3, 5, 7, 10], leadTable: 1, snare: true, arp: true),
        SongSpec(id: "rodeo", title: "Cactus Rodeo", blurb: "Country gallop", emoji: "🌵",
                 bpm: 140, root: 55, seed: 151,
                 chords: [Chord(root: 0, intervals: majT), Chord(root: 5, intervals: majT),
                          Chord(root: 0, intervals: majT), Chord(root: 7, intervals: majT)],
                 maxRhythm: 6, kickBeats: [0, 2], hatStep: 0.5, leadDecay: 6, group: "Cool originals",
                 snare: true),
        SongSpec(id: "aurora", title: "Aurora Borealis", blurb: "Floaty · dreamy lydian", emoji: "🌌",
                 bpm: 76, root: 60, seed: 163,
                 chords: [Chord(root: 0, intervals: majT), Chord(root: 2, intervals: majT),
                          Chord(root: 0, intervals: majT), Chord(root: 9, intervals: minT)],
                 maxRhythm: 3, kickBeats: [0], hatStep: 1, leadDecay: 2, group: "Cool originals",
                 scale: [0, 2, 4, 6, 9], arp: true, sustain: true)
    ]

    // Tunes: "note:beats" tokens, R = rest. Note names default to octave 4 (C4 = middle C).
    static let odeToJoy = [
        "E:1 E:1 F:1 G:1 G:1 F:1 E:1 D:1 C:1 C:1 D:1 E:1 E:1.5 D:.5 D:2",
        "E:1 E:1 F:1 G:1 G:1 F:1 E:1 D:1 C:1 C:1 D:1 E:1 D:1.5 C:.5 C:2",
        "D:1 D:1 E:1 C:1 D:1 E:.5 F:.5 E:1 C:1 D:1 E:.5 F:.5 E:1 D:1 C:1 D:1 G3:2",
        "E:1 E:1 F:1 G:1 G:1 F:1 E:1 D:1 C:1 C:1 D:1 E:1 D:1.5 C:.5 C:2"
    ].joined(separator: " ")
    static let twinkle = [
        "C:1 C:1 G:1 G:1 A:1 A:1 G:2 F:1 F:1 E:1 E:1 D:1 D:1 C:2",
        "G:1 G:1 F:1 F:1 E:1 E:1 D:2 G:1 G:1 F:1 F:1 E:1 E:1 D:2",
        "C:1 C:1 G:1 G:1 A:1 A:1 G:2 F:1 F:1 E:1 E:1 D:1 D:1 C:2"
    ].joined(separator: " ")
    static let jingleBells = [
        "E:1 E:1 E:2 E:1 E:1 E:2 E:1 G:1 C:1.5 D:.5 E:4",
        "F:1 F:1 F:1.5 F:.5 F:1 E:1 E:1 E:.5 E:.5 E:1 D:1 D:1 E:1 D:2 G:2"
    ].joined(separator: " ")
    static let saints = [
        "C:.5 E:.5 F:.5 G:2.5 C:.5 E:.5 F:.5 G:2.5",
        "C:.5 E:.5 F:.5 G:.5 E:.5 C:.5 E:.5 D:.5 D:.5 E:.5 D:.5 C:.5 C:2"
    ].joined(separator: " ")
    static let row = [
        "C:1 C:1 C:.75 D:.25 E:1 E:.75 D:.25 E:.75 F:.25 G:2",
        "C5:.5 C5:.5 C5:.5 G:.5 G:.5 G:.5 E:.5 E:.5 E:.5 C:.5 C:.5 C:.5",
        "G:.75 F:.25 E:.75 D:.25 C:2 R:2"
    ].joined(separator: " ")
    static let buns = [
        "E:1 D:1 C:2 E:1 D:1 C:2",
        "C:.5 C:.5 C:.5 C:.5 D:.5 D:.5 D:.5 D:.5 E:1 D:1 C:2"
    ].joined(separator: " ")
    static let london = [
        "G:1.5 A:.5 G:1 F:1 E:1 F:1 G:2",
        "D:1 E:1 F:2 E:1 F:1 G:2",
        "G:1.5 A:.5 G:1 F:1 E:1 F:1 G:2",
        "D:2 G:2 E:1 C:3"
    ].joined(separator: " ")
    static let susanna = [
        "C:.5 D:.5 E:1 G:1.5 G:.5",
        "A:.5 G:.5 E:1 C:1 D:1",
        "E:.5 E:.5 D:1 C:1 D:1",
        "D:3 R:1",
        "C:.5 D:.5 E:1 G:1.5 G:.5",
        "A:.5 G:.5 E:1 C:1 D:1",
        "E:.5 E:.5 D:1 D:1 C:1",
        "C:3 R:1"
    ].joined(separator: " ")
    static let mary = [
        "E:1 D:1 C:1 D:1 E:1 E:1 E:2 D:1 D:1 D:2 E:1 G:1 G:2",
        "E:1 D:1 C:1 D:1 E:1 E:1 E:1 E:1 D:1 D:1 E:1 D:1 C:4"
    ].joined(separator: " ")
}

struct MelodyNote { let beat: Double; let midi: Int; let dur: Double; var soundShift: Int = 0 }

struct RenderedSong {
    let spec: SongSpec
    let wav: Data
    let melody: [MelodyNote]
    let duration: Double
    let leadIn: Double
}

struct SplitMix64: RandomNumberGenerator {
    var state: UInt64
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

// MARK: - Synth

final class Mixer {
    static let sr = 44100.0
    var buf: [Float]
    var rng = SplitMix64(state: 99)

    init(seconds: Double) { buf = [Float](repeating: 0, count: Int(seconds * Mixer.sr)) }

    static func makeTable(_ harmonics: [Float]) -> [Float] {
        let n = 2048
        var t = [Float](repeating: 0, count: n)
        for i in 0..<n {
            var v: Float = 0
            for (h, a) in harmonics.enumerated() {
                v += a * sinf(2 * Float.pi * Float((h + 1) * i) / Float(n))
            }
            t[i] = v
        }
        let peak = t.map { abs($0) }.max() ?? 1
        return t.map { $0 / peak }
    }

    static let pure = makeTable([1])
    static let soft = makeTable([1, 0.35, 0.12])
    static let glock = makeTable([1, 0, 0.30, 0, 0.12])
    static let saw = makeTable([1, 0.5, 0.33, 0.25, 0.2, 0.167, 0.143, 0.125])

    func tone(_ table: [Float], start: Double, dur: Double, freq: Double, amp: Float,
              attack: Double, decay: Double, release: Double) {
        let sr = Mixer.sr
        let startIdx = Int(start * sr)
        let total = Int((dur + release) * sr)
        let n = table.count
        let mask = n - 1
        var phase = 0.0
        let inc = freq / sr * Double(n)
        let atk = max(1, Int(attack * sr))
        let relStart = Int(dur * sr)
        let relLen = max(1, Int(release * sr))
        let decayStep = Float(exp(-decay / sr))
        var dEnv: Float = 1
        table.withUnsafeBufferPointer { tb in
            buf.withUnsafeMutableBufferPointer { out in
                for i in 0..<total {
                    let idx = startIdx + i
                    if idx >= out.count { break }
                    let p = Int(phase)
                    let fr = Float(phase - Double(p))
                    let a = tb[p & mask], b = tb[(p + 1) & mask]
                    let s = a + (b - a) * fr
                    phase += inc
                    var env: Float = i < atk ? Float(i) / Float(atk) : 1
                    dEnv *= decayStep
                    env *= dEnv
                    if i > relStart { env *= max(0, 1 - Float(i - relStart) / Float(relLen)) }
                    out[idx] += s * env * amp
                }
            }
        }
    }

    func kick(start: Double, amp: Float) {
        let sr = Mixer.sr
        let startIdx = Int(start * sr)
        let n = Int(0.28 * sr)
        var ph = 0.0
        for i in 0..<n {
            let idx = startIdx + i
            if idx >= buf.count { break }
            let t = Double(i) / sr
            let f = 45 + 90 * exp(-t * 28)
            ph += f / sr
            buf[idx] += Float(sin(2 * Double.pi * ph) * exp(-t * 11)) * amp
        }
    }

    func snare(start: Double, amp: Float) {
        let sr = Mixer.sr
        let startIdx = Int(start * sr)
        let n = Int(0.16 * sr)
        for i in 0..<n {
            let idx = startIdx + i
            if idx >= buf.count { break }
            let t = Double(i) / sr
            let noise = Float.random(in: -1...1, using: &rng)
            let body = Float(sin(2 * Double.pi * 190 * t) * exp(-t * 30))
            buf[idx] += (noise * 0.7 * Float(exp(-t * 22)) + body * 0.5) * amp
        }
    }

    func hat(start: Double, amp: Float) {
        let sr = Mixer.sr
        let startIdx = Int(start * sr)
        let n = Int(0.05 * sr)
        var prev: Float = 0
        for i in 0..<n {
            let idx = startIdx + i
            if idx >= buf.count { break }
            let t = Double(i) / sr
            let noise = Float.random(in: -1...1, using: &rng)
            buf[idx] += (noise - prev) * 0.5 * Float(exp(-t * 70)) * amp
            prev = noise
        }
    }
}

func midiFreq(_ m: Int) -> Double { 440 * pow(2, Double(m - 69) / 12) }

enum SongRenderer {
    static let pent = [0, 2, 4, 7, 9]
    static let rhythms: [[Double]] = [
        [0, 1, 2, 3],
        [0, 1, 1.5, 2, 3],
        [0, 0.5, 1, 2, 2.5, 3],
        [0, 1, 2, 2.5, 3, 3.5],
        [0, 0.5, 1, 1.5, 2, 3],
        [0, 1.5, 2, 3],
        [0, 0.5, 1, 1.5, 2, 2.5, 3, 3.5]
    ]
    static let leadIn = 2.5
    static let bars = 32

    static func melodyMidi(_ spec: SongSpec, degree d: Int) -> Int {
        spec.root + 12 * (d / 5) + spec.scale[d % 5]
    }

    static func melody(for spec: SongSpec) -> [MelodyNote] {
        var out: [MelodyNote]
        switch spec.kind {
        case .generated: out = generated(spec)
        case .mountainKing: out = mountainKing()
        case .bumblebee: out = bumblebee()
        case .tune: out = tune(spec.tune)
        }
        let lastBar = Double(bars * 4 - 4)
        out.removeAll { $0.beat >= lastBar }
        out.append(MelodyNote(beat: lastBar, midi: spec.root + 12, dur: 4))
        return out
    }

    /// Grieg's theme, played slowly then twice as fast, then an octave higher.
    static func mountainKing() -> [MelodyNote] {
        let theme: [(Double, Int, Double)] = [
            (0, 59, 1), (1, 61, 1), (2, 62, 1), (3, 64, 1), (4, 66, 1), (5, 62, 1), (6, 66, 2),
            (8, 65, 1), (9, 61, 1), (10, 65, 1), (11, 64, 1), (12, 61, 1), (13, 64, 1), (14, 62, 2)]
        var out: [MelodyNote] = []
        var cur = 0.0
        func add(_ speed: Double, _ oct: Int, _ phrases: Int) {
            for _ in 0..<phrases {
                for n in theme { out.append(MelodyNote(beat: cur + n.0 / speed, midi: n.1 + oct, dur: n.2 / speed)) }
                cur += 16 / speed
            }
        }
        add(1, 0, 2); add(1, 12, 2); add(2, 0, 4); add(2, 12, 4)
        return out
    }

    static func parseTune(_ s: String) -> [(midi: Int?, dur: Double)] {
        let pcs: [Character: Int] = ["C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11]
        var out: [(midi: Int?, dur: Double)] = []
        for tok in s.split(separator: " ") {
            let parts = tok.split(separator: ":")
            guard parts.count == 2, let dur = Double(parts[1]) else { continue }
            let name = Array(parts[0])
            if name.first == "R" { out.append((nil, dur)); continue }
            guard let first = name.first, var pc = pcs[first] else { continue }
            var octave = 4
            for ch in name.dropFirst() {
                if ch == "#" { pc += 1 } else if ch == "b" { pc -= 1 } else if let d = ch.wholeNumberValue { octave = d }
            }
            out.append((12 * (octave + 1) + pc, dur))
        }
        return out
    }

    /// Repeats a tune to fill the song; every other pass sounds an octave higher.
    static func tune(_ s: String) -> [MelodyNote] {
        let toks = parseTune(s)
        var out: [MelodyNote] = []
        var cur = 0.0
        var cycle = 0
        while cur < Double(bars * 4) - 4 {
            for t in toks {
                if let m = t.midi {
                    out.append(MelodyNote(beat: cur, midi: m, dur: t.dur, soundShift: cycle % 2 == 1 ? 12 : 0))
                }
                cur += t.dur
            }
            cycle += 1
        }
        return out
    }

    /// Chromatic swarm runs around A, with a held note every fourth bar.
    static func bumblebee() -> [MelodyNote] {
        var out: [MelodyNote] = []
        let order = [[0, 1, 2, 3], [0, 2, 1, 3]]
        for bar in 0..<bars {
            let b = Double(bar * 4)
            let kind = order[bar >= 16 ? 1 : 0][bar % 4]
            switch kind {
            case 0, 2:
                let top = kind == 0 ? 76 : 74
                for i in 0..<8 { out.append(MelodyNote(beat: b + Double(i) * 0.5, midi: top - i, dur: 0.5)) }
            case 1:
                for i in 0..<8 { out.append(MelodyNote(beat: b + Double(i) * 0.5, midi: 69 + i, dur: 0.5)) }
            default:
                out.append(MelodyNote(beat: b, midi: 69, dur: 2))
                for i in 0..<4 { out.append(MelodyNote(beat: b + 2 + Double(i) * 0.5, midi: 70 + i, dur: 0.5)) }
            }
        }
        return out
    }

    static func generated(_ spec: SongSpec) -> [MelodyNote] {
        var rng = SplitMix64(state: spec.seed)
        let allowed = Array(rhythms.prefix(spec.maxRhythm))
        var phrases: [[MelodyNote]] = []
        var d = 4
        for _ in 0..<4 {
            var notes: [MelodyNote] = []
            for bar in 0..<4 {
                let r = (spec.sustain && bar == 2) ? [0, 2] : allowed.randomElement(using: &rng)!
                for (i, off) in r.enumerated() {
                    let next = i + 1 < r.count ? r[i + 1] : 4.0
                    let step = [-2, -1, -1, 0, 1, 1, 2].randomElement(using: &rng)!
                    d = max(0, min(9, d + step))
                    notes.append(MelodyNote(beat: Double(bar * 4) + off, midi: melodyMidi(spec, degree: d), dur: next - off))
                }
            }
            if let last = notes.popLast() {
                let end = [0, 2, 4, 5, 7].randomElement(using: &rng)!
                notes.append(MelodyNote(beat: last.beat, midi: melodyMidi(spec, degree: end), dur: last.dur))
                d = end
            }
            phrases.append(notes)
        }
        let seq = [0, 1, 0, 1, 2, 3, 2, 0]
        var out: [MelodyNote] = []
        for (pi, pidx) in seq.enumerated() {
            for n in phrases[pidx] {
                out.append(MelodyNote(beat: n.beat + Double(pi * 16), midi: n.midi, dur: n.dur))
            }
        }
        return out
    }

    static func render(_ spec: SongSpec) -> RenderedSong {
        let beat = 60 / spec.bpm
        let mel = melody(for: spec)
        let total = leadIn + Double(bars * 4) * beat + 3.0
        let m = Mixer(seconds: total)

        for bar in 0..<bars {
            let chord = spec.chords[bar % spec.chords.count]
            let barStart = leadIn + Double(bar * 4) * beat
            for iv in chord.intervals {
                let f = midiFreq(spec.root + chord.root + iv)
                m.tone(Mixer.soft, start: barStart, dur: 4 * beat, freq: f, amp: 0.05,
                       attack: 0.25, decay: 0, release: 0.5)
            }
            let bassMidi = spec.root - 12 + chord.root
            for (k, off) in [0.0, 1.5, 2.0, 3.0].enumerated() {
                let note = k == 2 ? bassMidi + 7 : bassMidi
                m.tone(Mixer.soft, start: barStart + off * beat, dur: 0.8 * beat, freq: midiFreq(note),
                       amp: 0.16, attack: 0.01, decay: 2.5, release: 0.12)
            }
            if spec.arp && bar >= 1 {
                let tones = chord.intervals.map { spec.root + 12 + chord.root + $0 } + [spec.root + 24 + chord.root]
                for i in 0..<8 {
                    m.tone(Mixer.pure, start: barStart + Double(i) * 0.5 * beat, dur: 0.3 * beat,
                           freq: midiFreq(tones[i % tones.count]), amp: 0.05, attack: 0.004, decay: 9, release: 0.1)
                }
            }
            if bar >= 1 {
                for kb in spec.kickBeats { m.kick(start: barStart + kb * beat, amp: 0.30) }
                if spec.snare {
                    m.snare(start: barStart + 1 * beat, amp: 0.20)
                    m.snare(start: barStart + 3 * beat, amp: 0.20)
                }
                var b = 0.0
                while b < 4 {
                    let accent: Float = b.truncatingRemainder(dividingBy: 1) == 0 ? 0.20 : 0.11
                    m.hat(start: barStart + b * beat, amp: accent)
                    b += spec.hatStep
                }
            }
        }

        for n in mel {
            let f = midiFreq(n.midi + n.soundShift)
            let start = leadIn + n.beat * beat
            if n.dur >= 1.5 {
                m.tone(Mixer.soft, start: start, dur: n.dur * beat, freq: f, amp: 0.20,
                       attack: 0.02, decay: 0.7, release: 0.35)
            } else {
                m.tone(spec.leadTable == 1 ? Mixer.saw : Mixer.glock, start: start, dur: min(n.dur * beat, 1.4), freq: f,
                       amp: spec.leadTable == 1 ? 0.13 : 0.22, attack: 0.004, decay: spec.leadDecay, release: 0.3)
                m.tone(Mixer.pure, start: start, dur: n.dur * beat * 0.6, freq: f * 2, amp: 0.05,
                       attack: 0.003, decay: 9, release: 0.15)
            }
        }

        // gentle echo for a dreamy feel
        let d = Int(beat * 0.75 * Mixer.sr)
        if d > 0 {
            for i in d..<m.buf.count { m.buf[i] += 0.26 * m.buf[i - d] }
        }

        let peak = m.buf.map { abs($0) }.max() ?? 1
        let scale = 0.9 / max(peak, 0.001)
        for i in 0..<m.buf.count { m.buf[i] *= scale }

        return RenderedSong(spec: spec, wav: wavData(m.buf), melody: mel,
                            duration: Double(m.buf.count) / Mixer.sr, leadIn: leadIn)
    }

    static func wavData(_ samples: [Float]) -> Data {
        var d = Data()
        let n = samples.count
        func u32(_ v: UInt32) { var x = v.littleEndian; withUnsafeBytes(of: &x) { d.append(contentsOf: $0) } }
        func u16(_ v: UInt16) { var x = v.littleEndian; withUnsafeBytes(of: &x) { d.append(contentsOf: $0) } }
        d.append("RIFF".data(using: .ascii)!)
        u32(UInt32(36 + n * 2))
        d.append("WAVEfmt ".data(using: .ascii)!)
        u32(16); u16(1); u16(1); u32(44100); u32(44100 * 2); u16(2); u16(16)
        d.append("data".data(using: .ascii)!)
        u32(UInt32(n * 2))
        var pcm = [Int16](repeating: 0, count: n)
        for i in 0..<n { pcm[i] = Int16(max(-1, min(1, samples[i])) * 32000) }
        pcm.withUnsafeBytes { d.append(contentsOf: $0) }
        return d
    }
}

// MARK: - Chart

struct GNote {
    let time: Double
    let lane: Int
    var dur: Double = 0          // > 0 means a hold note
    var resolved = false         // head judged (hit or missed)
    var hit = false
    var holding = false
    var holdDone = false
    var holdFailed = false
    var partner = -1             // index of a simultaneous (chord) note
    var isHold: Bool { dur > 0 }
    var end: Double { time + dur }
}

enum ChartBuilder {
    static func build(song: RenderedSong, lanes: Int) -> [GNote] {
        let beatSec = 60 / song.spec.bpm
        let lo = song.melody.map { $0.midi }.min() ?? 0
        let hi = song.melody.map { $0.midi }.max() ?? 1
        let range = max(1, hi - lo + 1)
        var busy = [Double](repeating: -10, count: lanes)
        var out: [GNote] = []
        for m in song.melody.sorted(by: { $0.beat < $1.beat }) {
            let frac = m.beat.truncatingRemainder(dividingBy: 1)
            let inBar = m.beat.truncatingRemainder(dividingBy: 4)
            let barIdx = Int(m.beat / 4)
            if lanes == 2 && frac != 0 { continue }
            if lanes == 3 && frac != 0 && !(inBar == 0.5 || inBar == 2.5) { continue }
            let lane = min(lanes - 1, (m.midi - lo) * lanes / range)
            let time = song.leadIn + m.beat * beatSec
            if time < busy[lane] + 0.12 { continue }
            let dur = m.dur >= 1.5 ? max(0.5, m.dur * beatSec - 0.15) : 0
            out.append(GNote(time: time, lane: lane, dur: dur))
            busy[lane] = time + dur
            let chordBar = lanes >= 4 ? 1 : 2
            if inBar == 0 && barIdx % chordBar == 0 && barIdx > 0 {
                let partner = (lane + max(1, lanes / 2)) % lanes
                if time >= busy[partner] + 0.12 {
                    out.append(GNote(time: time, lane: partner, dur: dur))
                    busy[partner] = time + dur
                }
            }
        }
        out.sort { $0.time < $1.time }
        for i in out.indices {
            for j in out.indices where j != i && abs(out[j].time - out[i].time) < 0.001 { out[i].partner = j }
        }
        return out
    }
}
