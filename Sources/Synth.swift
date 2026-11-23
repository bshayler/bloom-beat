import Foundation

// MARK: - Styles (instrument choices per song)

enum Lead { case bell, pluck, epiano, saw, flute, brass }
enum DrumKit { case none, gentle, pop, electro, hard }
enum BassKind { case pluck, sub, synth }

struct SynthStyle {
    var lead: Lead = .bell
    var drums: DrumKit = .gentle
    var bass: BassKind = .pluck
    var wet: Float = 0.30        // reverb amount
    var pad: Float = 0.075       // pad level
    var pump = false             // sidechain-style ducking of pads and arps on every kick
    var harmony = false          // quiet octave-up double on the lead
    var echo: Float = 0.16       // ping-pong echo amount
    var comp = false             // rhythmic chord stabs / strums behind the melody

    static let table: [String: SynthStyle] = [
        "dew": SynthStyle(lead: .epiano, drums: .gentle, bass: .pluck, wet: 0.35, pad: 0.08),
        "sun": SynthStyle(lead: .pluck, drums: .pop, bass: .pluck, wet: 0.25, comp: true),
        "rain": SynthStyle(lead: .bell, drums: .pop, bass: .pluck, wet: 0.35, harmony: true, comp: true),
        "moon": SynthStyle(lead: .epiano, drums: .gentle, bass: .pluck, wet: 0.50, pad: 0.10, echo: 0.24),
        "firefly": SynthStyle(lead: .bell, drums: .pop, bass: .sub, wet: 0.30, pad: 0.06, harmony: true),
        "petal": SynthStyle(lead: .saw, drums: .electro, bass: .synth, wet: 0.22, pump: true, echo: 0.12, comp: true),
        "neon": SynthStyle(lead: .saw, drums: .electro, bass: .synth, wet: 0.30, pump: true, harmony: true, comp: true),
        "funk": SynthStyle(lead: .saw, drums: .pop, bass: .synth, wet: 0.20, echo: 0.1, comp: true),
        "sakura": SynthStyle(lead: .pluck, drums: .gentle, bass: .pluck, wet: 0.45, pad: 0.09, echo: 0.22),
        "thunder": SynthStyle(lead: .saw, drums: .electro, bass: .synth, wet: 0.22, pump: true, echo: 0.12, comp: true),
        "rodeo": SynthStyle(lead: .pluck, drums: .pop, bass: .pluck, wet: 0.15, echo: 0.08, comp: true),
        "aurora": SynthStyle(lead: .epiano, drums: .gentle, bass: .pluck, wet: 0.55, pad: 0.085, echo: 0.28),
        "king": SynthStyle(lead: .pluck, drums: .pop, bass: .pluck, wet: 0.30),
        "bee": SynthStyle(lead: .saw, drums: .gentle, bass: .pluck, wet: 0.25),
        "ode": SynthStyle(lead: .flute, drums: .gentle, bass: .pluck, wet: 0.40, harmony: true, echo: 0.2),
        "twinkle": SynthStyle(lead: .bell, drums: .none, bass: .pluck, wet: 0.45, echo: 0.2),
        "jingle": SynthStyle(lead: .bell, drums: .pop, bass: .pluck, wet: 0.30),
        "saints": SynthStyle(lead: .brass, drums: .pop, bass: .pluck, wet: 0.25),
        "mary": SynthStyle(lead: .pluck, drums: .gentle, bass: .pluck, wet: 0.35),
        "row": SynthStyle(lead: .flute, drums: .none, bass: .pluck, wet: 0.40),
        "buns": SynthStyle(lead: .pluck, drums: .gentle, bass: .pluck, wet: 0.30),
        "london": SynthStyle(lead: .epiano, drums: .gentle, bass: .pluck, wet: 0.40),
        "susanna": SynthStyle(lead: .pluck, drums: .pop, bass: .pluck, wet: 0.20),
        // hard mode
        "thorn": SynthStyle(lead: .saw, drums: .hard, bass: .synth, wet: 0.18, pad: 0.06, pump: true, echo: 0.10, comp: true),
        "bramble": SynthStyle(lead: .saw, drums: .hard, bass: .synth, wet: 0.20, pad: 0.06, pump: true, harmony: true, echo: 0.12, comp: true),
        "cyclone": SynthStyle(lead: .saw, drums: .hard, bass: .synth, wet: 0.22, pump: true, echo: 0.14, comp: true),
        "nightshade": SynthStyle(lead: .saw, drums: .hard, bass: .synth, wet: 0.30, pad: 0.08, pump: true, harmony: true, echo: 0.20, comp: true),
        "gallop": SynthStyle(lead: .pluck, drums: .hard, bass: .pluck, wet: 0.15, pad: 0.05, echo: 0.08, comp: true),
        "hydra": SynthStyle(lead: .saw, drums: .hard, bass: .synth, wet: 0.20, pump: true, harmony: true, echo: 0.16, comp: true),
        "overgrowth": SynthStyle(lead: .pluck, drums: .pop, bass: .pluck, wet: 0.28, pad: 0.06, harmony: true, echo: 0.14),
        "turkish": SynthStyle(lead: .pluck, drums: .pop, bass: .pluck, wet: 0.22, echo: 0.10)
    ]

    static func style(for spec: SongSpec) -> SynthStyle { table[spec.id] ?? SynthStyle() }
}

// MARK: - Stereo mixer with instruments, drums and reverb

final class StereoMixer {
    static let sr: Float = 44100
    static let srD = 44100.0
    let n: Int
    var dryL: [Float], dryR: [Float]       // always-on bus
    var padL: [Float], padR: [Float]       // pads/arps (ducked by kicks)
    var send: [Float]                      // mono reverb send
    var rng = SplitMix64(state: 12345)
    var kickSamples: [Int] = []
    var scratch: [Float]

    static let sawTable: [Float] = {
        let size = 2048
        var t = [Float](repeating: 0, count: size)
        for i in 0..<size {
            var v: Float = 0
            for h in 1...20 { v += sinf(2 * Float.pi * Float(h * i) / Float(size)) / Float(h) }
            t[i] = v
        }
        let peak = t.map { abs($0) }.max() ?? 1
        return t.map { $0 / peak }
    }()

    init(seconds: Double) {
        n = Int(seconds * StereoMixer.srD)
        dryL = [Float](repeating: 0, count: n); dryR = dryL
        padL = dryL; padR = dryL; send = dryL
        scratch = [Float](repeating: 0, count: Int(8 * StereoMixer.srD))
    }

    @inline(__always) func noise() -> Float { Float.random(in: -1...1, using: &rng) }
    /// Tiny timing wobble for drums and bass so they feel played, not programmed (never used on the melody).
    func jitter() -> Double { Double(Float.random(in: -0.007...0.007, using: &rng)) }
    func vel(_ lo: Float = 0.78) -> Float { Float.random(in: lo...1.05, using: &rng) }

    /// Mix the first `len` samples of scratch into the buses.
    func commit(start: Double, len: Int, pan: Float, sendAmt: Float, pad: Bool) {
        let s0 = Int(start * StereoMixer.srD)
        if s0 >= n || len <= 0 { return }
        let a = (pan + 1) * Float.pi / 4
        let gl = cosf(a), gr = sinf(a)
        let end = min(n, s0 + len)
        for i in s0..<end {
            let x = scratch[i - s0]
            if pad { padL[i] += x * gl; padR[i] += x * gr } else { dryL[i] += x * gl; dryR[i] += x * gr }
            send[i] += x * sendAmt
        }
    }

    func capLen(_ seconds: Double, start: Double) -> Int {
        let maxLen = min(scratch.count, Int(seconds * StereoMixer.srD))
        let s0 = Int(start * StereoMixer.srD)
        return max(0, min(maxLen, n - s0))
    }

    // MARK: Instruments

    /// FM bell / music box.
    func bell(_ start: Double, freq: Double, amp: Float, decay: Float, pan: Float, sendAmt: Float,
              ratio: Float = 3.5, index: Float = 2.4) {
        let len = capLen(Double(min(5.5 / decay, 3.0)), start: start)
        let w = 2 * Float.pi * Float(freq) / StereoMixer.sr
        var ph: Float = 0, phm: Float = 0
        var e: Float = 1
        let eStep = expf(-decay / StereoMixer.sr)
        var ie: Float = 1
        let ieStep = expf(-5.5 / StereoMixer.sr)
        for i in 0..<len {
            let m = sinf(phm) * (index * ie + 0.15)
            let atk = min(1, Float(i) / 90)
            scratch[i] = sinf(ph + m) * e * amp * atk
            ph += w; phm += w * ratio
            e *= eStep; ie *= ieStep
        }
        commit(start: start, len: len, pan: pan, sendAmt: sendAmt, pad: false)
    }

    /// Karplus-Strong plucked string (harp, banjo, pizzicato, bass).
    func pluck(_ start: Double, freq: Double, amp: Float, decay: Float, bright: Float, pan: Float,
               sendAmt: Float, pad: Bool = false) {
        let D = Float(StereoMixer.srD / freq) - 0.5
        let size = Int(D) + 4
        var b = [Float](repeating: 0, count: size)
        var prev: Float = 0
        for k in 0..<size {
            let x = noise()
            prev += (x - prev) * bright          // brighter = less smoothing of the excitation
            b[k] = prev
        }
        let g = min(0.9996, max(0.90, expf(-decay / Float(freq))))
        let len = capLen(Double(min(5.0 / decay, 2.8)), start: start)
        var w = 0
        for i in 0..<len {
            let r1 = Float(w) - D
            let r2 = r1 - 1
            let y1 = interp(b, r1, size), y2 = interp(b, r2, size)
            let y = g * 0.5 * (y1 + y2)
            b[w] = y
            w += 1; if w == size { w = 0 }
            scratch[i] = y * amp * 1.6 * min(1, Float(i) / 40)
        }
        commit(start: start, len: len, pan: pan, sendAmt: sendAmt, pad: pad)
    }

    @inline(__always) private func interp(_ b: [Float], _ pos: Float, _ size: Int) -> Float {
        var p = pos
        while p < 0 { p += Float(size) }
        let i0 = Int(p) % size
        let i1 = (i0 + 1) % size
        let f = p - floorf(p)
        return b[i0] + (b[i1] - b[i0]) * f
    }

    /// FM electric piano.
    func epiano(_ start: Double, dur: Double, freq: Double, amp: Float, pan: Float, sendAmt: Float) {
        let len = capLen(min(dur + 0.4, 3.2), start: start)
        let w = 2 * Float.pi * Float(freq) / StereoMixer.sr
        var ph: Float = 0
        var e: Float = 1
        let eStep = expf(-1.7 / StereoMixer.sr)
        var ie: Float = 1
        let ieStep = expf(-4.5 / StereoMixer.sr)
        var ce: Float = 1
        let ceStep = expf(-9.0 / StereoMixer.sr)
        let relStart = Int(dur * StereoMixer.srD)
        let relLen = Int(0.3 * StereoMixer.srD)
        for i in 0..<len {
            let tine = sinf(ph) * (2.0 * ie + 0.35)
            let body = sinf(ph + tine)
            let chime = 0.18 * sinf(4 * ph) * ce
            var env = e * min(1, Float(i) / 110)
            if i > relStart { env *= max(0, 1 - Float(i - relStart) / Float(relLen)) }
            scratch[i] = (body + chime) * env * amp
            ph += w
            e *= eStep; ie *= ieStep; ce *= ceStep
        }
        commit(start: start, len: len, pan: pan, sendAmt: sendAmt, pad: false)
    }

    /// Detuned saw voice through a low-pass filter with a cutoff sweep (leads, brass, pads, bass).
    func saw(_ start: Double, dur: Double, freq: Double, amp: Float, attack: Double, decay: Float,
             cutStart: Float, cutEnd: Float, cutTau: Float, release: Double, vibrato: Float = 0,
             detuneCents: Float = 6, pan: Float, sendAmt: Float, pad: Bool = false) {
        let len = capLen(dur + release + 0.05, start: start)
        let table = StereoMixer.sawTable
        let tn = table.count
        let f1 = Float(freq) * powf(2, detuneCents / 1200)
        let f2 = Float(freq) * powf(2, -detuneCents / 1200)
        var p1: Float = 0, p2: Float = Float(tn) * 0.37
        var y: Float = 0
        let atk = max(1, Int(attack * StereoMixer.srD))
        let relStart = Int(dur * StereoMixer.srD)
        let relLen = max(1, Int(release * StereoMixer.srD))
        var de: Float = 1
        let deStep = expf(-decay / StereoMixer.sr)
        for i in 0..<len {
            let t = Float(i) / StereoMixer.sr
            let vib = vibrato > 0 ? 1 + vibrato * sinf(2 * Float.pi * 5.3 * t) * min(1, t * 3) : 1
            let i1 = Int(p1) & (tn - 1), i2 = Int(p2) & (tn - 1)
            let s = (table[i1] + table[i2]) * 0.5
            p1 += f1 * vib / StereoMixer.sr * Float(tn)
            p2 += f2 * vib / StereoMixer.sr * Float(tn)
            let fc = cutEnd + (cutStart - cutEnd) * expf(-t / cutTau)
            let a = 1 - expf(-2 * Float.pi * min(fc, 18000) / StereoMixer.sr)
            y += a * (s - y)
            var env = min(1, Float(i) / Float(atk)) * de
            if i > relStart { env *= max(0, 1 - Float(i - relStart) / Float(relLen)) }
            scratch[i] = y * env * amp
            de *= deStep
        }
        commit(start: start, len: len, pan: pan, sendAmt: sendAmt, pad: pad)
    }

    /// Breathy flute.
    func flute(_ start: Double, dur: Double, freq: Double, amp: Float, pan: Float, sendAmt: Float) {
        let release = 0.18
        let len = capLen(dur + release + 0.05, start: start)
        let w = 2 * Float.pi * Float(freq) / StereoMixer.sr
        var ph: Float = 0
        var lp: Float = 0
        let atk = Int(0.06 * StereoMixer.srD)
        let relStart = Int(dur * StereoMixer.srD)
        let relLen = Int(release * StereoMixer.srD)
        for i in 0..<len {
            let t = Float(i) / StereoMixer.sr
            let vib = 1 + 0.004 * sinf(2 * Float.pi * 5.2 * t) * min(1, max(0, t - 0.15) * 3)
            let tone = sinf(ph) + 0.22 * sinf(2 * ph) + 0.06 * sinf(3 * ph)
            lp += (noise() - lp) * 0.25
            var env = min(1, Float(i) / Float(max(atk, 1)))
            if i > relStart { env *= max(0, 1 - Float(i - relStart) / Float(relLen)) }
            scratch[i] = (tone * 0.8 + lp * 0.10) * env * amp
            ph += w * vib
        }
        commit(start: start, len: len, pan: pan, sendAmt: sendAmt, pad: false)
    }

    func subBass(_ start: Double, dur: Double, freq: Double, amp: Float) {
        let len = capLen(dur + 0.15, start: start)
        let w = 2 * Float.pi * Float(freq) / StereoMixer.sr
        var ph: Float = 0
        let relStart = Int(dur * StereoMixer.srD)
        let relLen = Int(0.12 * StereoMixer.srD)
        var e: Float = 1
        let eStep = expf(-2.2 / StereoMixer.sr)
        for i in 0..<len {
            var env = e * min(1, Float(i) / 200)
            if i > relStart { env *= max(0, 1 - Float(i - relStart) / Float(relLen)) }
            scratch[i] = (sinf(ph) + 0.55 * sinf(2 * ph) + 0.2 * sinf(3 * ph)) * env * amp
            ph += w
            e *= eStep
        }
        commit(start: start, len: len, pan: 0, sendAmt: 0, pad: false)
    }

    // MARK: Drums

    func kick(_ start: Double, amp: Float) {
        let len = capLen(0.32, start: start)
        var ph: Float = 0
        for i in 0..<len {
            let t = Float(i) / StereoMixer.sr
            let f = 46 + 120 * expf(-t * 32)
            ph += 2 * Float.pi * f / StereoMixer.sr
            let click = noise() * expf(-t * 260) * 0.25
            scratch[i] = (sinf(ph) * expf(-t * 8.5) + click) * amp
        }
        commit(start: start, len: len, pan: 0, sendAmt: 0.02, pad: false)
        kickSamples.append(Int(start * StereoMixer.srD))
    }

    func snare(_ start: Double, amp: Float) {
        let len = capLen(0.28, start: start)
        var prev: Float = 0
        for i in 0..<len {
            let t = Float(i) / StereoMixer.sr
            let nz = noise()
            let hp = nz - prev * 0.55
            prev = nz
            let body = sinf(2 * Float.pi * 185 * t) * expf(-t * 26)
            scratch[i] = (hp * 0.55 * expf(-t * 18) + body * 0.5) * amp
        }
        commit(start: start, len: len, pan: 0.05, sendAmt: 0.22, pad: false)
    }

    func clap(_ start: Double, amp: Float) {
        let len = capLen(0.3, start: start)
        var prev: Float = 0
        for i in 0..<len {
            let t = Float(i) / StereoMixer.sr
            let nz = noise()
            let hp = nz - prev * 0.7
            prev = nz
            let bursts = expf(-fmodf(t, 0.012) * 260) * (t < 0.036 ? 1 : 0)
            let tail = expf(-t * 16) * 0.6
            scratch[i] = hp * (bursts * 0.8 + tail) * amp
        }
        commit(start: start, len: len, pan: 0, sendAmt: 0.30, pad: false)
    }

    func hat(_ start: Double, amp: Float, open: Bool = false, pan: Float = 0.25) {
        let len = capLen(open ? 0.3 : 0.07, start: start)
        let k: Float = open ? 13 : 85
        var prev: Float = 0
        for i in 0..<len {
            let t = Float(i) / StereoMixer.sr
            let nz = noise()
            let hp = nz - prev * 0.92
            prev = nz
            scratch[i] = hp * 0.5 * expf(-t * k) * amp
        }
        commit(start: start, len: len, pan: pan, sendAmt: open ? 0.12 : 0.03, pad: false)
    }

    func shaker(_ start: Double, amp: Float, pan: Float) {
        let len = capLen(0.1, start: start)
        var prev: Float = 0
        for i in 0..<len {
            let t = Float(i) / StereoMixer.sr
            let nz = noise()
            let hp = nz - prev * 0.85
            prev = nz
            scratch[i] = hp * 0.4 * (min(1, t * 80) * expf(-t * 38)) * amp
        }
        commit(start: start, len: len, pan: pan, sendAmt: 0.06, pad: false)
    }

    func crash(_ start: Double, amp: Float) {
        let len = capLen(1.8, start: start)
        var prev: Float = 0
        for i in 0..<len {
            let t = Float(i) / StereoMixer.sr
            let nz = noise()
            let hp = nz - prev * 0.88
            prev = nz
            scratch[i] = hp * 0.45 * expf(-t * 2.6) * amp
        }
        commit(start: start, len: len, pan: -0.1, sendAmt: 0.35, pad: false)
    }

    // MARK: Reverb (Freeverb-style) and master

    private func reverb(_ input: [Float]) -> (l: [Float], r: [Float]) {
        let combTunings = [1116, 1188, 1277, 1356, 1422, 1491, 1557, 1617]
        let allpassTunings = [556, 441, 341, 225]
        let spread = 23
        let feedback: Float = 0.86
        let damp: Float = 0.25

        func run(spreadSamples: Int) -> [Float] {
            var out = [Float](repeating: 0, count: input.count)
            var combs: [(buf: [Float], idx: Int, store: Float)] = combTunings.map { ([Float](repeating: 0, count: $0 + spreadSamples), 0, 0) }
            var aps: [(buf: [Float], idx: Int)] = allpassTunings.map { ([Float](repeating: 0, count: $0 + spreadSamples), 0) }
            for i in 0..<input.count {
                let x = input[i] * 0.015
                var acc: Float = 0
                for c in 0..<combs.count {
                    let o = combs[c].buf[combs[c].idx]
                    combs[c].store = o * (1 - damp) + combs[c].store * damp
                    combs[c].buf[combs[c].idx] = x + combs[c].store * feedback
                    combs[c].idx += 1; if combs[c].idx == combs[c].buf.count { combs[c].idx = 0 }
                    acc += o
                }
                for a in 0..<aps.count {
                    let bufOut = aps[a].buf[aps[a].idx]
                    let o = -acc + bufOut
                    aps[a].buf[aps[a].idx] = acc + bufOut * 0.5
                    aps[a].idx += 1; if aps[a].idx == aps[a].buf.count { aps[a].idx = 0 }
                    acc = o
                }
                out[i] = acc
            }
            return out
        }
        return (run(spreadSamples: 0), run(spreadSamples: spread))
    }

    /// Reverb, ducking, filtering, soft clip and normalisation. Returns interleaved stereo samples.
    func master(style: SynthStyle, fadeOut: Double, beat: Double) -> [Float] {
        let (rl, rr) = reverb(send)

        // ping-pong echo: dotted eighth to the left, quarter to the right, each repeat a little darker
        var dlyL = [Float](repeating: 0, count: n), dlyR = [Float](repeating: 0, count: n)
        if style.echo > 0 {
            let dL = max(1, Int(0.75 * beat * StereoMixer.srD)), dR = max(1, Int(1.0 * beat * StereoMixer.srD))
            var lpL: Float = 0, lpR: Float = 0
            for i in 0..<n {
                let x = send[i] * 0.5
                lpR += ((i >= dR ? dlyR[i - dR] : 0) - lpR) * 0.45
                lpL += ((i >= dL ? dlyL[i - dL] : 0) - lpL) * 0.45
                dlyL[i] = x + 0.42 * lpR
                dlyR[i] = 0.42 * lpL
            }
        }
        let echoGain = style.echo * 2
        var comp: Float = 0
        let cAtk = expf(-1 / (0.010 * StereoMixer.sr)), cRel = expf(-1 / (0.14 * StereoMixer.sr))
        var duck = [Float](repeating: 1, count: n)
        if style.pump {
            let len = Int(0.22 * StereoMixer.srD)
            for k in kickSamples {
                for j in 0..<len where k + j < n {
                    // dip right after the kick, then recover smoothly
                    let v = 0.4 + 0.6 * (1 - expf(-Float(j) / (0.07 * StereoMixer.sr)))
                    if v < duck[k + j] { duck[k + j] = v }
                }
            }
        }
        let wetGain = style.wet * 2.6
        var out = [Float](repeating: 0, count: n * 2)
        var xl: Float = 0, xr: Float = 0, yl: Float = 0, yr: Float = 0
        var peak: Float = 0.0001
        let fadeStart = n - Int(fadeOut * StereoMixer.srD)
        for i in 0..<n {
            var l = dryL[i] + padL[i] * duck[i] + rl[i] * wetGain + dlyL[i] * echoGain
            var r = dryR[i] + padR[i] * duck[i] + rr[i] * wetGain + dlyR[i] * echoGain
            // remove DC and sub-rumble
            let nl = l - xl + 0.996 * yl; xl = l; yl = nl; l = nl
            let nr = r - xr + 0.996 * yr; xr = r; yr = nr; r = nr
            // gentle glue compression
            let lvl = max(abs(l), abs(r))
            comp = lvl > comp ? lvl + cAtk * (comp - lvl) : lvl + cRel * (comp - lvl)
            let g: Float = comp > 0.2 ? powf(comp / 0.2, 1 / 2.4 - 1) : 1
            l *= g; r *= g
            l = tanhf(l * 1.2); r = tanhf(r * 1.2)
            if i > fadeStart {
                let g = max(0, 1 - Float(i - fadeStart) / Float(max(1, n - fadeStart)))
                l *= g; r *= g
            }
            if i < 2000 { let g = Float(i) / 2000; l *= g; r *= g }
            out[2 * i] = l; out[2 * i + 1] = r
            peak = max(peak, abs(l), abs(r))
        }
        let scale = 0.9 / peak
        for i in 0..<out.count { out[i] *= scale }
        return out
    }
}

// MARK: - Arranger

enum Synth {
    static func render(spec: SongSpec, melody mel: [MelodyNote], bars: Int, leadIn: Double) -> (wav: Data, duration: Double) {
        let st = SynthStyle.style(for: spec)
        let beat = 60 / spec.bpm
        let total = leadIn + Double(bars * 4) * beat + 4.0
        let m = StereoMixer(seconds: total)

        var prevVoicing: [Int] = []
        for bar in 0..<bars {
            let chord = spec.chords[bar % spec.chords.count]
            let nextChord = spec.chords[(bar + 1) % spec.chords.count]
            let t0 = leadIn + Double(bar * 4) * beat
            // build in, bigger middle section, fade at the end
            let lift: Float = (bar >= 16 && bar < 24) ? 1.15 : 1.0
            let tail: Float = bar >= 28 ? max(0.35, 1 - Float(bar - 27) * 0.14) : 1
            let sec: Float = (bar < 2 ? 0.6 : (bar < 4 ? 0.85 : 1.0)) * lift * tail

            // voice-led chord: each voice moves to the nearest note of the next chord, like a keyboard player would
            let voicing = voiceLead(chord.intervals.map { spec.root + chord.root + $0 }, prev: prevVoicing, center: spec.root + 3)
            prevVoicing = voicing

            // pad: three detuned saws per chord tone, slow swell
            for (k, midi) in voicing.enumerated() {
                m.saw(t0, dur: 4 * beat, freq: midiFreq(midi), amp: st.pad * sec, attack: 0.45, decay: 0,
                      cutStart: 1100, cutEnd: 1100, cutTau: 1, release: 0.7, detuneCents: 8,
                      pan: [-0.55, 0, 0.55][k % 3], sendAmt: 0.25, pad: true)
            }

            // a fourth pad voice: the root an octave up, for fullness
            m.saw(t0, dur: 4 * beat, freq: midiFreq(spec.root + chord.root + 12), amp: st.pad * sec * 0.55, attack: 0.55, decay: 0,
                  cutStart: 1000, cutEnd: 1000, cutTau: 1, release: 0.8, detuneCents: 6, pan: 0.12, sendAmt: 0.25, pad: true)

            // bass: root / fifth / octave, with an approach note that walks into the next chord
            let bassMidi = spec.root - 12 + chord.root
            let nextRoot = spec.root - 12 + nextChord.root
            let rootF = midiFreq(bassMidi), fifthF = midiFreq(bassMidi + 7), octF = midiFreq(bassMidi + 12)
            let approachF = midiFreq(nextRoot == bassMidi ? bassMidi + 12 : nextRoot + (bar % 2 == 0 ? -1 : 1))
            switch st.bass {
            case .pluck:
                var pattern: [(Double, Double, Float)]
                switch st.drums {
                case .none, .gentle:
                    pattern = [(0, rootF, 1), (2, bar % 2 == 0 ? fifthF : rootF, 0.9)]
                    if bar % 2 == 1 { pattern.append((3.5, approachF, 0.75)) }
                default:
                    pattern = bar % 2 == 0
                        ? [(0, rootF, 1), (1.5, rootF, 0.8), (2, fifthF, 0.95), (3, rootF, 0.9)]
                        : [(0, rootF, 1), (1, octF, 0.8), (2, fifthF, 0.95), (2.5, rootF, 0.7), (3.5, approachF, 0.85)]
                }
                for (off, f, a) in pattern {
                    m.pluck(t0 + off * beat + m.jitter(), freq: f, amp: 0.20 * sec * m.vel(0.88) * a, decay: 3.5, bright: 0.40, pan: -0.05, sendAmt: 0.04)
                }
            case .sub:
                let pattern: [(Double, Double)] = bar % 2 == 0
                    ? [(0, rootF), (1, rootF), (2, fifthF), (3, rootF)]
                    : [(0, rootF), (1, rootF), (2, fifthF), (2.5, rootF), (3.5, approachF)]
                for (i, (off, f)) in pattern.enumerated() {
                    let nextOff = i + 1 < pattern.count ? pattern[i + 1].0 : 4
                    m.subBass(t0 + off * beat + m.jitter(), dur: min(0.85, nextOff - off - 0.05) * beat, freq: f, amp: 0.17 * sec)
                }
            case .synth:
                let steps = st.drums == .hard ? 16 : 8
                let per = steps / 4
                for i in 0..<steps {
                    let octave = steps == 8 ? (i % 4 == 3) : (i % 8 == 3 || i % 8 == 7)
                    var f = octave ? octF : rootF
                    if i == steps - 1 && bar % 2 == 1 { f = approachF }
                    let o = Double(i) * 4.0 / Double(steps) * beat
                    let accent: Float = i % per == 0 ? 1.15 : 0.9
                    m.saw(t0 + o, dur: 0.84 * 4.0 / Double(steps) * beat, freq: f, amp: 0.12 * sec * accent, attack: 0.004, decay: 3,
                          cutStart: 1200, cutEnd: 220, cutTau: 0.07, release: 0.05, detuneCents: 4,
                          pan: 0, sendAmt: 0.02)
                    if steps == 8 || i % per == 0 {
                        m.subBass(t0 + o, dur: 0.4 * beat, freq: rootF, amp: 0.08 * sec)
                    }
                }
            }

            // drums
            if bar >= 1 {
                let fill = bar % 4 == 3 && bar >= 3
                switch st.drums {
                case .none: break
                case .gentle:
                    m.kick(t0 + m.jitter(), amp: 0.18 * sec * m.vel(0.9))
                    for i in 0..<4 { m.shaker(t0 + Double(i) * beat + m.jitter(), amp: (i % 2 == 0 ? 0.20 : 0.13) * m.vel(), pan: i % 2 == 0 ? -0.2 : 0.2) }
                case .pop:
                    for kb in spec.kickBeats { m.kick(t0 + kb * beat + m.jitter(), amp: 0.26 * m.vel(0.92)) }
                    if bar % 2 == 1 { m.kick(t0 + 3.5 * beat + m.jitter(), amp: 0.16 * m.vel(0.9)) }
                    m.snare(t0 + 1 * beat + m.jitter(), amp: 0.20 * m.vel(0.9))
                    m.snare(t0 + 3 * beat + m.jitter(), amp: 0.20 * m.vel(0.9))
                    if fill { for (o, a) in [(3.5, 0.13), (3.75, 0.18)] as [(Double, Float)] { m.snare(t0 + o * beat + m.jitter(), amp: a * m.vel(0.9)) } }
                    if bar % 8 == 0 { m.crash(t0, amp: 0.22) }
                    var b = 0.0
                    while b < 4 {
                        let accent: Float = b.truncatingRemainder(dividingBy: 1) == 0 ? 0.20 : 0.11
                        m.hat(t0 + b * beat + m.jitter(), amp: accent * m.vel())
                        b += max(0.5, spec.hatStep)
                    }
                case .electro:
                    for kb in [0.0, 1.0, 2.0, 3.0] { m.kick(t0 + kb * beat + m.jitter() * 0.5, amp: 0.25 * m.vel(0.95)) }
                    m.clap(t0 + 1 * beat + m.jitter(), amp: 0.22 * m.vel(0.9))
                    m.clap(t0 + 3 * beat + m.jitter(), amp: 0.22 * m.vel(0.9))
                    if fill { for (o, a) in [(3.5, 0.14), (3.75, 0.18)] as [(Double, Float)] { m.clap(t0 + o * beat, amp: a) } }
                    for off in [0.5, 1.5, 2.5, 3.5] { m.hat(t0 + off * beat, amp: 0.20, open: true) }
                    for i in 0..<16 where i % 2 == 1 { m.hat(t0 + Double(i) * 0.25 * beat, amp: 0.07) }
                    if bar % 8 == 0 { m.crash(t0, amp: 0.30) }
                case .hard:
                    // double-time rock/electro kit: syncopated kick, snare on 2 and 4, sixteenth hats, a roll every fourth bar
                    let kicks: [Double] = bar % 2 == 0 ? [0, 0.75, 2, 2.5, 3.25] : [0, 0.5, 1.5, 2, 2.75, 3.5]
                    for kb in kicks { m.kick(t0 + kb * beat + m.jitter() * 0.5, amp: 0.25 * m.vel(0.93)) }
                    m.snare(t0 + 1 * beat + m.jitter(), amp: 0.22 * m.vel(0.9))
                    if fill {
                        for j in 0..<4 { m.snare(t0 + (3 + Double(j) * 0.25) * beat, amp: (0.13 + 0.04 * Float(j)) * m.vel(0.9)) }
                    } else {
                        m.snare(t0 + 3 * beat + m.jitter(), amp: 0.22 * m.vel(0.9))
                    }
                    for i in 0..<16 {
                        let a: Float = i % 4 == 0 ? 0.17 : (i % 2 == 0 ? 0.11 : 0.07)
                        m.hat(t0 + Double(i) * 0.25 * beat, amp: a * m.vel(), open: i % 8 == 6)
                    }
                    if bar % 8 == 0 { m.crash(t0, amp: 0.30) }
                }
            }

            // chord stabs (electro/hard) or strums (pop): the harmony that makes the groove feel like a band
            if st.comp && bar >= 2 {
                let stab = st.drums == .electro || st.drums == .hard
                let offs: [Double] = stab ? [0.5, 1.5, 2.5, 3.5] : [1.5, 3.5]
                for off in offs {
                    for (k, midi) in voicing.enumerated() {
                        let t = t0 + off * beat + Double(k) * 0.008
                        if stab {
                            m.saw(t, dur: 0.22 * beat, freq: midiFreq(midi + 12), amp: 0.035 * sec, attack: 0.004, decay: 6,
                                  cutStart: 3200, cutEnd: 600, cutTau: 0.05, release: 0.05, detuneCents: 7,
                                  pan: [-0.3, 0, 0.3][k % 3], sendAmt: 0.12, pad: true)
                        } else {
                            m.pluck(t, freq: midiFreq(midi + 12), amp: 0.06 * sec, decay: 7, bright: 0.35,
                                    pan: [-0.35, 0, 0.35][k % 3], sendAmt: 0.15, pad: true)
                        }
                    }
                }
            }

            // arpeggio sparkle
            if spec.arp && bar >= 1 {
                let tones = chord.intervals.map { spec.root + 12 + chord.root + $0 } + [spec.root + 24 + chord.root]
                for i in 0..<8 {
                    m.pluck(t0 + Double(i) * 0.5 * beat, freq: midiFreq(tones[i % tones.count]), amp: 0.06 * sec,
                            decay: 9, bright: 0.5, pan: i % 2 == 0 ? -0.45 : 0.45, sendAmt: 0.30, pad: true)
                }
            }
        }

        // melody
        for n in mel {
            let f = midiFreq(n.midi + n.soundShift)
            let start = leadIn + n.beat * beat
            let isHold = n.dur >= 1.5
            let dur = n.dur * beat
            let pan = max(-0.4, min(0.4, Float(n.midi - 62) / 32))
            let decay = Float(max(2.0, min(8.0, spec.leadDecay)))
            // phrasing: downbeats lean in, offbeats sit back, with a touch of human variation
            let inBar = n.beat.truncatingRemainder(dividingBy: 4)
            let acc: Float = (inBar == 0 ? 1.12 : (n.beat.truncatingRemainder(dividingBy: 1) == 0 ? 1.0 : 0.86))
                * Float.random(in: 0.95...1.03, using: &m.rng)

            if isHold {
                switch st.lead {
                case .saw, .brass:
                    m.saw(start, dur: dur * 0.97, freq: f, amp: 0.20, attack: 0.04, decay: 0.25,
                          cutStart: 700, cutEnd: 2400, cutTau: 0.25, release: 0.25, vibrato: 0.005,
                          detuneCents: 7, pan: pan, sendAmt: 0.30)
                default:
                    m.flute(start, dur: dur * 0.97, freq: f, amp: 0.2, pan: pan, sendAmt: 0.32)
                }
            } else {
                switch st.lead {
                case .bell:
                    m.bell(start, freq: f, amp: 0.21 * acc, decay: decay * 0.8, pan: pan, sendAmt: 0.32)
                case .pluck:
                    m.pluck(start, freq: f, amp: 0.30 * acc, decay: decay * 0.9, bright: 0.45, pan: pan, sendAmt: 0.28)
                case .epiano:
                    m.epiano(start, dur: min(dur, 1.2), freq: f, amp: 0.22 * acc, pan: pan, sendAmt: 0.30)
                case .saw:
                    m.saw(start, dur: min(dur, 1.0), freq: f, amp: 0.21 * acc, attack: 0.005, decay: decay * 0.7,
                          cutStart: 5200, cutEnd: 1800, cutTau: 0.10, release: 0.12, detuneCents: 9,
                          pan: pan, sendAmt: 0.28)
                case .flute:
                    m.flute(start, dur: min(dur * 0.92, 1.4), freq: f, amp: 0.2 * acc, pan: pan, sendAmt: 0.32)
                case .brass:
                    m.saw(start, dur: min(dur * 0.9, 1.0), freq: f, amp: 0.21 * acc, attack: 0.03, decay: 1.0,
                          cutStart: 600, cutEnd: 2600, cutTau: 0.07, release: 0.08, vibrato: 0.004,
                          detuneCents: 5, pan: pan, sendAmt: 0.28)
                }
            }
            let barIdx = Int(n.beat / 4)
            if (st.harmony || (barIdx >= 16 && barIdx < 24)) && !isHold {
                m.bell(start, freq: f * 2, amp: 0.045, decay: 5, pan: -pan, sendAmt: 0.35, ratio: 2.0, index: 1.2)
            }
        }

        let pcm = m.master(style: st, fadeOut: 2.2, beat: beat)
        return (wavData(pcm), Double(pcm.count / 2) / StereoMixer.srD)
    }

    /// Moves each chord tone to the octave nearest the previous chord's matching voice (smooth voice leading),
    /// keeping the whole voicing close to `center`.
    static func voiceLead(_ tones: [Int], prev: [Int], center: Int) -> [Int] {
        var out: [Int] = []
        for (i, t) in tones.enumerated() {
            let target = i < prev.count ? prev[i] : center
            var best = t, bestDist = Int.max
            for k in -4...4 {
                let c = t + 12 * k
                if abs(c - target) < bestDist { bestDist = abs(c - target); best = c }
            }
            out.append(best)
        }
        let avg = out.reduce(0, +) / max(1, out.count)
        if avg > center + 7 { out = out.map { $0 - 12 } } else if avg < center - 7 { out = out.map { $0 + 12 } }
        return out
    }

    /// 16-bit stereo PCM WAV from interleaved samples.
    static func wavData(_ samples: [Float]) -> Data {
        var d = Data()
        let n = samples.count
        func u32(_ v: UInt32) { var x = v.littleEndian; withUnsafeBytes(of: &x) { d.append(contentsOf: $0) } }
        func u16(_ v: UInt16) { var x = v.littleEndian; withUnsafeBytes(of: &x) { d.append(contentsOf: $0) } }
        d.append("RIFF".data(using: .ascii)!)
        u32(UInt32(36 + n * 2))
        d.append("WAVEfmt ".data(using: .ascii)!)
        u32(16); u16(1); u16(2); u32(44100); u32(44100 * 4); u16(4); u16(16)
        d.append("data".data(using: .ascii)!)
        u32(UInt32(n * 2))
        var pcm = [Int16](repeating: 0, count: n)
        for i in 0..<n { pcm[i] = Int16(max(-1, min(1, samples[i])) * 32000) }
        pcm.withUnsafeBytes { d.append(contentsOf: $0) }
        return d
    }
}
