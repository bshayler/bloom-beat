import SceneKit
import UIKit
import simd

// MARK: - 3D plant model (step 3 of the SceneKit port)
//
// Builds the potted plant from PlantGeometry and animates it from the same inputs the 2D `drawPlant` takes:
// health (0...1), wilt (0...1), time and the stage-up `pop`. It is a port of buildPlant() in
// Design/plant-studio-reference.html.
//
// Performance rule: meshes are rebuilt ONLY when the flower or the growth phase (seedling, sprout, bud,
// flower) changes. Everything that changes every frame (stem height and bend, leaf and petal angles, sizes,
// wilt tint, sway) is done with node transforms and material colours, never by rebuilding geometry.
//
// Units: the pot is about 2.2 wide and 1.22 tall with its base at y = 0. Flower ids match the game:
// 3 daisy, 4 tulip, 5 cherry blossom, 6 sunflower.

final class PlantModel {
    /// Add this to a scene. Origin is the centre of the base of the pot, +Y is up.
    let root = SCNNode()

    private(set) var flower: Int
    private var phase = -1                 // 0 seedling, 1 sprout, 2 bud, 3 flower; -1 = not built yet

    private let plantBase = SCNNode()      // sits on the soil line; sways and pops
    private var joints: [SCNNode] = []     // stem chain, joints[jointCount] is the tip that carries the head
    private var segments: [SCNNode] = []   // one stem mesh per joint, scaled to the current stem length
    private var leaves: [LeafRef] = []
    private var petals: [PetalRef] = []
    private var head: SCNNode?
    private var tintMaterials: [SCNMaterial] = []

    private let jointCount = 8
    private let soilY: Float = 1.1

    private struct LeafRef {
        let node: SCNNode
        let joint: Int            // which stem joint carries it
        let along: Float          // 0...1 position along that joint's segment
        let az: Float
        let baseTilt: Float
        let wiltGain: Float
    }

    private struct PetalRef {
        let node: SCNNode
        let az: Float
        let baseTilt: Float
        let wiltGain: Float
    }

    // MARK: Tables (same numbers as the mockup; one entry per growth threshold, last entry is health 1.0)

    private static let thresholds: [Double] = [0, 0.18, 0.34, 0.50, 0.66, 0.84, 1.0]
    private static let stemHeight: [Double] = [0.30, 0.85, 1.50, 1.75, 2.15, 2.55, 2.75]
    private static let headScale:  [Double] = [0, 0, 0.5, 0.55, 0.8, 1.0, 1.1]
    private static let leafScale:  [Double] = [0.35, 0.6, 0.8, 0.9, 1.0, 1.05, 1.12]

    private static func table(_ values: [Double], _ h: Double) -> Double {
        var i = 0
        while i < 5 && h >= thresholds[i + 1] { i += 1 }
        let f = (h - thresholds[i]) / (thresholds[i + 1] - thresholds[i])
        return values[i] + (values[i + 1] - values[i]) * min(1, max(0, f))
    }

    // MARK: Init

    init(flower: Int = 3) {
        self.flower = flower
        root.addChildNode(makePot())
        plantBase.position = SCNVector3(0, soilY, 0)
        root.addChildNode(plantBase)
    }

    // MARK: Update (call every frame; cheap unless the flower or phase changed)

    /// - health: 0...1 growth
    /// - wilt: 0...1 droop and browning
    /// - time: seconds, drives the gentle sway
    /// - pop: 1 right after a stage-up, decaying to 0
    func update(health: Double, wilt: Double, time: Double = 0, pop: Double = 0, flower newFlower: Int? = nil) {
        let target = newFlower ?? flower
        let newPhase = min(PlantStage.index(for: health), 3)
        if target != flower || newPhase != phase {
            flower = target
            phase = newPhase
            rebuild()
        }
        apply(health: health, wilt: wilt, time: time, pop: pop)
    }

    // MARK: Per-frame transforms

    private func apply(health h: Double, wilt w: Double, time: Double, pop: Double) {
        let wf = Float(w)
        let height = Float(Self.table(Self.stemHeight, h))
        let segLen = height / Float(jointCount)
        let growth = Float(0.55 + 0.45 * min(1, Double(height) / 2.4))
        let stemR = stemRadius * growth

        // stem: lengths and radii
        for i in 0..<jointCount {
            let r = stemR * (1 - 0.3 * Float(i) / Float(jointCount))
            segments[i].simdScale = SIMD3<Float>(r, segLen, r)
            joints[i + 1].simdPosition = SIMD3<Float>(0, segLen, 0)
        }

        // stem: lean plus wilt droop, spread over the joints (rotating about Z leans the plant towards +X)
        let leanTotal = atan(2 * leanAmount)
        func angle(_ s: Float) -> Float { leanTotal * s + wf * 2.0 * powf(s, 1.7) }
        var previous: Float = 0
        for i in 0..<jointCount {
            let mid = angle((Float(i) + 0.5) / Float(jointCount))
            joints[i].simdOrientation = simd_quatf(angle: -(mid - previous), axis: SIMD3<Float>(0, 0, 1))
            previous = mid
        }
        joints[jointCount].simdOrientation = simd_quatf(angle: -(angle(1) - previous), axis: SIMD3<Float>(0, 0, 1))

        // leaves
        let ls = Float(Self.table(Self.leafScale, h))
        for leaf in leaves {
            leaf.node.simdPosition = SIMD3<Float>(0, leaf.along * segLen, 0)
            leaf.node.simdOrientation = orient(az: leaf.az, tilt: leaf.baseTilt + leaf.wiltGain * wf)
            leaf.node.simdScale = SIMD3<Float>(repeating: leaf.node.name == "cotyledon" ? (0.36 * ls + 0.1) / 0.46 : ls)
        }

        // head
        if let head = head {
            let tilt: Float
            switch flower {
            case 3: tilt = 0.1
            case 4: tilt = 0.0
            case 5: tilt = 0.3
            default: tilt = 0.62
            }
            let flowerFactor: Float = [3: 1.2, 4: 0.78, 5: 1.05, 6: 1.2][flower] ?? 1
            let budFactor: Float = phase == 2 ? 0.9 : 1
            head.simdOrientation = simd_quatf(angle: tilt + (phase == 2 ? -0.1 : 0) + wf * 0.5, axis: SIMD3<Float>(1, 0, 0))
            head.simdScale = SIMD3<Float>(repeating: Float(Self.table(Self.headScale, h)) * flowerFactor * budFactor)
        }
        for petal in petals {
            petal.node.simdOrientation = orient(az: petal.az, tilt: petal.baseTilt + petal.wiltGain * wf)
        }

        // wilt colour: multiply every plant material towards a dry brown
        let tint = UIColor(red: 1 - 0.38 * CGFloat(w), green: 1 - 0.50 * CGFloat(w), blue: 1 - 0.62 * CGFloat(w), alpha: 1)
        for m in tintMaterials { m.multiply.contents = tint }

        // sway (fades out as the plant wilts) and the stage-up pop
        let sway = (1 - wf) * 0.012
        plantBase.simdEulerAngles = SIMD3<Float>(Float(cos(time * 1.1)) * sway, 0, Float(sin(time * 1.3)) * sway)
        plantBase.simdScale = SIMD3<Float>(repeating: 1 + 0.08 * Float(pop))
    }

    // MARK: Build

    private var stemRadius: Float {
        [3: 0.05, 4: 0.06, 5: 0.045, 6: 0.1][flower] ?? 0.05
    }
    private var leanAmount: Float {
        [3: 0.12, 4: 0.05, 5: 0.2, 6: 0.06][flower] ?? 0.1
    }

    private func orient(az: Float, tilt: Float) -> simd_quatf {
        // tilt about X first, then spin about the vertical axis (the mockup's 'YXZ' Euler order)
        simd_quatf(angle: az, axis: SIMD3<Float>(0, 1, 0)) * simd_quatf(angle: tilt, axis: SIMD3<Float>(1, 0, 0))
    }

    private func rebuild() {
        plantBase.childNodes.forEach { $0.removeFromParentNode() }
        joints = []; segments = []; leaves = []; petals = []; head = nil; tintMaterials = []
        var rng = SeededRandom(seed: UInt32(flower * 97 + 5))

        // stem chain
        let stemColor = PlantColor.hex(flower == 6 ? 0x5d9a3a : 0x468a38)
        let stemGeometry = register(PlantGeometry.tube(length: 1, bottomRadius: 1, topRadius: 0.94, sides: 10, color: stemColor))
        var parent = plantBase
        for i in 0...jointCount {
            let joint = SCNNode()
            parent.addChildNode(joint)
            joints.append(joint)
            if i < jointCount {
                let seg = SCNNode(geometry: stemGeometry)
                joint.addChildNode(seg)
                segments.append(seg)
            }
            parent = joint
        }

        buildLeaves(rng: &rng)

        if phase >= 2 {
            let h = phase == 2 ? makeBud() : makeHead()
            joints[jointCount].addChildNode(h)
            head = h
        }
    }

    // MARK: Leaves

    private func attach(_ node: SCNNode, t: Float, az: Float, baseTilt: Float, wiltGain: Float) {
        let scaled = min(0.98, max(0, t)) * Float(jointCount)
        let k = min(jointCount - 1, Int(scaled))
        joints[k].addChildNode(node)
        leaves.append(LeafRef(node: node, joint: k, along: scaled - Float(k), az: az, baseTilt: baseTilt, wiltGain: wiltGain))
    }

    private func buildLeaves(rng: inout SeededRandom) {
        let lc0 = PlantColor.hex(0x2b7330), lc1 = PlantColor.hex(0x7dc243)

        if phase < 3 {
            let coty = register(PlantGeometry.blade(BladeSpec(length: 0.46, width: 0.33, curl: 0.15, fold: 0.2, profile: .oval,
                                                              baseColor: PlantColor.hex(0x3c8a35), tipColor: PlantColor.hex(0x9bd35a), segments: 6)))
            for i in 0..<2 {
                let node = SCNNode(geometry: coty)
                node.name = "cotyledon"
                attach(node, t: phase == 0 ? 1 : 0.55, az: Float(i) * .pi + 0.4, baseTilt: 1.1, wiltGain: 0.5)
            }
        }
        guard phase >= 1 else { return }

        let count = phase == 1 ? 3 : ([3: 8, 4: 4, 5: 7, 6: 6][flower] ?? 6)
        for i in 0..<count {
            let t: Double = phase == 1 ? 0.35 + Double(i) * 0.22
                : (flower == 4 ? 0.02 + Double(i) * 0.015 : 0.05 + 0.8 * Double(i) / Double(count))
            let az = Float(Double(i) * 2.399 + rng.next() * 0.4)
            let sz = (phase == 1 ? 0.9 : 1.0) * (0.85 + rng.next() * 0.3) * (1 - 0.35 * min(0.98, t))

            var spec: BladeSpec
            var tilt: Float, gain: Float = 0.6
            switch flower {
            case 4:
                spec = BladeSpec(length: 1.6 * sz, width: 0.42 * sz, curl: 0.5, fold: 0.22, profile: .strap, baseColor: lc0, tipColor: lc1, segments: 14)
                tilt = 0.38 + Float(i) * 0.17; gain = 0.7
            case 6:
                spec = BladeSpec(length: 1.0 * sz, width: 0.95 * sz, curl: 0.35, fold: 0.12, wave: 0.05, profile: .heart, baseColor: lc0, tipColor: lc1)
                tilt = 0.9
            case 5:
                spec = BladeSpec(length: 0.85 * sz, width: 0.42 * sz, curl: 0.3, fold: 0.15, profile: .oval, baseColor: lc0, tipColor: lc1, segments: 10)
                tilt = 0.95
            default:
                spec = BladeSpec(length: 1.0 * sz, width: 0.5 * sz, curl: 0.28, fold: 0.18, wave: 0.04, profile: .oval, baseColor: lc0, tipColor: lc1)
                tilt = 0.85
            }
            if phase == 1 {
                spec = BladeSpec(length: 0.55 * sz, width: 0.34 * sz, curl: 0.3, profile: .oval, baseColor: lc0, tipColor: lc1, segments: 8)
            }

            let geometry = PlantGeometry.blade(spec)
            let node = SCNNode()
            if flower == 6 && phase >= 2 {
                // sunflower leaves hang off a short stalk
                let petioleLength = Float(0.4 * sz)
                let petiole = SCNNode(geometry: register(PlantGeometry.tube(length: petioleLength, bottomRadius: 0.026, topRadius: 0.018, sides: 6, color: PlantColor.hex(0x4f8f3a))))
                node.addChildNode(petiole)
                let blade = SCNNode(geometry: register(geometry))
                blade.position = SCNVector3(0, Float(0.38 * sz), 0)
                node.addChildNode(blade)
            } else {
                node.geometry = register(geometry)
            }
            attach(node, t: Float(t), az: az, baseTilt: tilt, wiltGain: gain)
        }
    }

    // MARK: Flower heads (local +Y is the direction the stem is growing)

    private func makeBlade(_ spec: BladeSpec) -> SCNGeometry { register(PlantGeometry.blade(spec)) }

    private func petalRing(_ head: SCNNode, n: Int, offset: Float, r0: Float, tilt: Float, gain: Float,
                           geometry: SCNGeometry, lift: Float = 0) {
        for i in 0..<n {
            let az = offset + Float(i) / Float(n) * 2 * .pi
            let node = SCNNode(geometry: geometry)
            node.simdPosition = SIMD3<Float>(sinf(az) * r0, lift, cosf(az) * r0)
            node.simdOrientation = orient(az: az, tilt: tilt)
            head.addChildNode(node)
            if gain > 0 { petals.append(PetalRef(node: node, az: az, baseTilt: tilt, wiltGain: gain)) }
        }
    }

    private func solid(_ geometry: SCNGeometry, _ color: UIColor, roughness: CGFloat = 0.7) -> SCNNode {
        let m = SCNMaterial()
        m.lightingModel = .physicallyBased
        m.diffuse.contents = color
        m.roughness.contents = roughness
        m.metalness.contents = 0.0
        geometry.materials = [m]
        tintMaterials.append(m)
        return SCNNode(geometry: geometry)
    }

    private func stamens(_ head: SCNNode, n: Int, length: Float, spread: Float, tip: UIColor, stalk: UIColor,
                         thickness: Float = 0.012, y: Float = 0) {
        for i in 0..<n {
            let az = Float(i) / Float(n) * 2 * .pi + Float(i) * 0.37
            let lean = spread * (0.6 + 0.4 * Float((i * 7) % 5) / 4)
            let group = SCNNode()
            group.simdOrientation = orient(az: az, tilt: lean)
            group.simdPosition = SIMD3<Float>(0, y, 0)
            let rodGeometry = SCNCylinder(radius: CGFloat(thickness), height: CGFloat(length))
            rodGeometry.radialSegmentCount = 6
            let rod = solid(rodGeometry, stalk, roughness: 0.6)
            rod.position = SCNVector3(0, length / 2, 0)
            let capGeometry = SCNSphere(radius: CGFloat(thickness * 2.2))
            capGeometry.segmentCount = 8
            let cap = solid(capGeometry, tip, roughness: 0.5)
            cap.position = SCNVector3(0, length, 0)
            group.addChildNode(rod)
            group.addChildNode(cap)
            head.addChildNode(group)
        }
    }

    private func makeHead() -> SCNNode {
        switch flower {
        case 4: return headTulip()
        case 5: return headCherry()
        case 6: return headSunflower()
        default: return headDaisy()
        }
    }

    private func headDaisy() -> SCNNode {
        let g = SCNNode()
        func petal(_ len: Double, _ wid: Double, _ c0: UInt32, _ c1: UInt32) -> SCNGeometry {
            makeBlade(BladeSpec(length: len, width: wid, curl: 0.18, fold: 0.12, profile: .ray,
                                baseColor: PlantColor.hex(c0), tipColor: PlantColor.hex(c1), segments: 8))
        }
        petalRing(g, n: 17, offset: 0.1, r0: 0.16, tilt: 1.38, gain: 0.6, geometry: petal(0.78, 0.2, 0xfff1a8, 0xffffff), lift: -0.02)
        petalRing(g, n: 17, offset: 0.1 + .pi / 17, r0: 0.14, tilt: 1.22, gain: 0.6, geometry: petal(0.66, 0.19, 0xffe98a, 0xfffdf2), lift: 0.012)
        let disc = solid(SCNSphere(radius: 0.25), PlantColor.hex(0xe8a90c), roughness: 0.8)
        disc.scale = SCNVector3(1, 0.5, 1)
        disc.position = SCNVector3(0, 0.01, 0)
        g.addChildNode(disc)
        let seeds = SCNNode(geometry: register(PlantGeometry.seedDisc(count: 110, radius: 0.22, dome: 0.09, seedSize: 0.026, y: 0.02) { f, i in
            f < 0.35 ? PlantColor.hex(0xb9650f) : (i % 3 != 0 ? PlantColor.hex(0xf7c21b) : PlantColor.hex(0xe39a10))
        }))
        g.addChildNode(seeds)
        let sepal = makeBlade(BladeSpec(length: 0.3, width: 0.12, curl: 0.3, profile: .oval,
                                        baseColor: PlantColor.hex(0x2f7d32), tipColor: PlantColor.hex(0x6fb04a), segments: 4))
        petalRing(g, n: 8, offset: 0, r0: 0.06, tilt: 2.3, gain: 0, geometry: sepal, lift: -0.05)
        return g
    }

    private func headTulip() -> SCNNode {
        let g = SCNNode()
        let outer = makeBlade(BladeSpec(length: 1.25, width: 0.7, curl: 0.34, fold: 0.1, profile: .petal,
                                        baseColor: PlantColor.hex(0x9d1630), tipColor: PlantColor.hex(0xff5a6a)))
        let inner = makeBlade(BladeSpec(length: 1.12, width: 0.62, curl: 0.3, fold: 0.12, profile: .petal,
                                        baseColor: PlantColor.hex(0xb3203a), tipColor: PlantColor.hex(0xff7482)))
        petalRing(g, n: 3, offset: 0, r0: 0.14, tilt: 0.2, gain: 0.45, geometry: outer)
        petalRing(g, n: 3, offset: .pi / 3, r0: 0.1, tilt: 0.1, gain: 0.36, geometry: inner, lift: 0.03)
        stamens(g, n: 6, length: 0.5, spread: 0.12, tip: PlantColor.hex(0xd6b62a), stalk: PlantColor.hex(0x7a8f2c), y: 0.02)
        return g
    }

    private func headCherry() -> SCNNode {
        let g = SCNNode()
        let a = makeBlade(BladeSpec(length: 0.85, width: 0.78, curl: 0.32, fold: 0.16, notch: 0.14, profile: .wide,
                                    baseColor: PlantColor.hex(0xee5a8c), tipColor: PlantColor.hex(0xffe6ef), segments: 10))
        let b = makeBlade(BladeSpec(length: 0.74, width: 0.7, curl: 0.3, fold: 0.15, notch: 0.13, profile: .wide,
                                    baseColor: PlantColor.hex(0xf27aa3), tipColor: PlantColor.hex(0xfff2f6), segments: 10))
        petalRing(g, n: 5, offset: 0, r0: 0.07, tilt: 0.98, gain: 0.55, geometry: a)
        petalRing(g, n: 5, offset: .pi / 5, r0: 0.05, tilt: 0.8, gain: 0.55, geometry: b, lift: 0.04)
        stamens(g, n: 16, length: 0.36, spread: 0.7, tip: PlantColor.hex(0xc0264f), stalk: PlantColor.hex(0xf4a8c0), thickness: 0.008, y: 0.06)
        let centre = solid(SCNSphere(radius: 0.06), PlantColor.hex(0x9fbf3d), roughness: 0.6)
        centre.position = SCNVector3(0, 0.08, 0)
        g.addChildNode(centre)
        return g
    }

    private func headSunflower() -> SCNNode {
        let g = SCNNode()
        func ray(_ len: Double, _ wid: Double, _ c0: UInt32, _ c1: UInt32) -> SCNGeometry {
            makeBlade(BladeSpec(length: len, width: wid, curl: 0.12, fold: 0.1, profile: .ray,
                                baseColor: PlantColor.hex(c0), tipColor: PlantColor.hex(c1), segments: 8))
        }
        petalRing(g, n: 26, offset: 0, r0: 0.58, tilt: 1.45, gain: 0.6, geometry: ray(0.8, 0.2, 0xf59a0b, 0xffd23d), lift: -0.03)
        petalRing(g, n: 26, offset: .pi / 26, r0: 0.55, tilt: 1.3, gain: 0.6, geometry: ray(0.7, 0.21, 0xee8e08, 0xffc42b), lift: 0.02)
        let plate = PlantGeometry.lathe(profile: [SIMD2<Float>(0, 0.05), SIMD2<Float>(0.66, 0.05), SIMD2<Float>(0.6, -0.05), SIMD2<Float>(0, -0.05)],
                                        sides: 40, color: PlantColor.hex(0x3a2412), roughness: 0.9)
        g.addChildNode(SCNNode(geometry: register(plate)))
        let seeds = PlantGeometry.seedDisc(count: 520, radius: 0.64, dome: 0.14, seedSize: 0.034, y: 0.05) { f, i in
            if f < 0.25 { return PlantColor.hex(0x2a170a) }
            if f < 0.8 { return i % 2 == 0 ? PlantColor.hex(0x4b2a12) : PlantColor.hex(0x3a2010) }
            return i % 2 == 0 ? PlantColor.hex(0x8a5a1e) : PlantColor.hex(0xb5841f)
        }
        g.addChildNode(SCNNode(geometry: register(seeds)))
        let bract = makeBlade(BladeSpec(length: 0.36, width: 0.22, curl: 0.25, profile: .ray,
                                        baseColor: PlantColor.hex(0x2f7d32), tipColor: PlantColor.hex(0x6aa83f), segments: 4))
        petalRing(g, n: 14, offset: 0, r0: 0.4, tilt: 2.5, gain: 0, geometry: bract, lift: -0.06)
        return g
    }

    private func makeBud() -> SCNNode {
        let g = SCNNode()
        let colors: [Int: UInt32] = [3: 0xfff0f3, 4: 0xd4263e, 5: 0xf7a1be, 6: 0xa8c43a]
        let bud = solid(SCNSphere(radius: 0.5), PlantColor.hex(colors[flower] ?? 0xfff0f3), roughness: 0.55)
        bud.scale = SCNVector3(0.8, 1.25, 0.8)
        bud.position = SCNVector3(0, 0.5, 0)
        g.addChildNode(bud)
        let sepal = makeBlade(BladeSpec(length: 0.6, width: 0.34, curl: -0.05, profile: .oval,
                                        baseColor: PlantColor.hex(0x2f7d32), tipColor: PlantColor.hex(0x78b84a), segments: 6))
        for i in 0..<5 {
            let az = Float(i) / 5 * 2 * .pi
            let node = SCNNode(geometry: sepal)
            node.simdOrientation = orient(az: az, tilt: 0.28)
            node.simdPosition = SIMD3<Float>(sinf(az) * 0.18, 0, cosf(az) * 0.18)
            g.addChildNode(node)
        }
        return g
    }

    // MARK: Pot

    private func makePot() -> SCNNode {
        let pot = SCNNode()
        pot.addChildNode(SCNNode(geometry: PlantGeometry.pot()))
        // lighter band under the rim
        let band = PlantGeometry.lathe(profile: [SIMD2<Float>(1.03, 0.95), SIMD2<Float>(1.10, 1.05)], sides: 56,
                                       color: PlantColor.hex(0xd77a4f), roughness: 0.8)
        pot.addChildNode(SCNNode(geometry: band))
        // soil
        let soil = SCNNode(geometry: PlantGeometry.lathe(profile: [SIMD2<Float>(0, soilY), SIMD2<Float>(0.92, soilY)], sides: 40,
                                                         color: PlantColor.hex(0x3f2a1b), roughness: 1))
        pot.addChildNode(soil)
        // a few pebbles on the soil
        var rng = SeededRandom(seed: 1234)
        for _ in 0..<9 {
            let size = 0.05 + rng.next() * 0.04
            let sphere = SCNSphere(radius: CGFloat(size))
            sphere.segmentCount = 8
            let m = SCNMaterial()
            m.lightingModel = .physicallyBased
            m.diffuse.contents = PlantColor.hex(0x6b5136)
            m.roughness.contents = 0.9
            sphere.materials = [m]
            let node = SCNNode(geometry: sphere)
            let a = rng.next() * 6.28, r = 0.2 + rng.next() * 0.6
            node.position = SCNVector3(Float(cos(a) * r), soilY + 0.02, Float(sin(a) * r))
            pot.addChildNode(node)
        }
        pot.enumerateHierarchy { n, _ in n.castsShadow = true }
        return pot
    }

    /// Keeps track of a geometry's material so the wilt tint reaches it.
    private func register(_ geometry: SCNGeometry) -> SCNGeometry {
        if let m = geometry.materials.first { tintMaterials.append(m) }
        return geometry
    }
}

// MARK: - Small deterministic random numbers (port of the mockup's mulberry32)

struct SeededRandom {
    private var state: UInt32

    init(seed: UInt32) { state = seed }

    mutating func next() -> Double {
        state = state &+ 0x6D2B79F5
        var t = state
        t = (t ^ (t >> 15)) &* (t | 1)
        t = (t &+ ((t ^ (t >> 7)) &* (t | 61))) ^ t
        return Double(t ^ (t >> 14)) / 4294967296.0
    }
}
