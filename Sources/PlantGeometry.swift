import SceneKit
import UIKit
import simd

// MARK: - Procedural geometry for the 3D plants
//
// Step 2 of the SceneKit port. Everything here is pure geometry: no scene, no animation, no game state.
// It is a Swift port of the helpers in Design/plant-studio-reference.html (blade, lathe, phyllotaxis), so the
// shapes match the approved mockups. Axes are the same as in the mockup (right-handed, +Y up).

// MARK: Mesh accumulator

/// Vertices, per-vertex colours and triangles collected on the CPU, then turned into one `SCNGeometry`.
/// Normals are the area-weighted average of the faces that share a vertex.
struct PlantMesh {
    var positions: [SIMD3<Float>] = []
    var colors: [SIMD4<Float>] = []
    var indices: [Int32] = []

    @discardableResult
    mutating func addVertex(_ p: SIMD3<Float>, color: SIMD4<Float>) -> Int32 {
        positions.append(p)
        colors.append(color)
        return Int32(positions.count - 1)
    }

    mutating func addTriangle(_ a: Int32, _ b: Int32, _ c: Int32) {
        indices.append(contentsOf: [a, b, c])
    }

    /// Builds the geometry with a single physically based material. Vertex colours tint a white diffuse.
    func makeGeometry(doubleSided: Bool = true, roughness: CGFloat = 0.62) -> SCNGeometry {
        var normals = [SIMD3<Float>](repeating: .zero, count: positions.count)
        var i = 0
        while i + 2 < indices.count {
            let a = Int(indices[i]), b = Int(indices[i + 1]), c = Int(indices[i + 2])
            let n = simd_cross(positions[b] - positions[a], positions[c] - positions[a])
            normals[a] += n
            normals[b] += n
            normals[c] += n
            i += 3
        }
        for k in normals.indices {
            let len = simd_length(normals[k])
            normals[k] = len > 1e-8 ? normals[k] / len : SIMD3<Float>(0, 1, 0)
        }

        let vertexSource = SCNGeometrySource(vertices: positions.map { SCNVector3($0.x, $0.y, $0.z) })
        let normalSource = SCNGeometrySource(normals: normals.map { SCNVector3($0.x, $0.y, $0.z) })
        let colorData = colors.withUnsafeBufferPointer { Data(buffer: $0) }
        let colorSource = SCNGeometrySource(data: colorData,
                                            semantic: .color,
                                            vectorCount: colors.count,
                                            usesFloatComponents: true,
                                            componentsPerVector: 4,
                                            bytesPerComponent: MemoryLayout<Float>.size,
                                            dataOffset: 0,
                                            dataStride: MemoryLayout<SIMD4<Float>>.stride)
        let element = SCNGeometryElement(indices: indices, primitiveType: .triangles)
        let geometry = SCNGeometry(sources: [vertexSource, normalSource, colorSource], elements: [element])

        let material = SCNMaterial()
        material.lightingModel = .physicallyBased
        material.diffuse.contents = UIColor.white
        material.roughness.contents = roughness
        material.metalness.contents = 0.0
        material.isDoubleSided = doubleSided
        geometry.materials = [material]
        return geometry
    }
}

// MARK: Colour helpers

enum PlantColor {
    /// Vertex colours are read as linear values. The mockup colours are sRGB hex, so they are converted.
    /// If the plants look washed out or too dark on a device, flip this and compare.
    static var convertToLinear = true

    static func rgba(_ color: UIColor, alpha: Float = 1) -> SIMD4<Float> {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        func lin(_ v: CGFloat) -> Float {
            let x = Float(v)
            guard convertToLinear else { return x }
            return x <= 0.04045 ? x / 12.92 : powf((x + 0.055) / 1.055, 2.4)
        }
        return SIMD4<Float>(lin(r), lin(g), lin(b), alpha)
    }

    static func mix(_ a: SIMD4<Float>, _ b: SIMD4<Float>, _ t: Float) -> SIMD4<Float> {
        a + (b - a) * min(1, max(0, t))
    }

    /// Hex like 0x2f7d32.
    static func hex(_ value: UInt32) -> UIColor {
        UIColor(red: CGFloat((value >> 16) & 0xff) / 255,
                green: CGFloat((value >> 8) & 0xff) / 255,
                blue: CGFloat(value & 0xff) / 255,
                alpha: 1)
    }
}

// MARK: Blades (leaves and petals)

/// Width of a blade along its length, `t` runs 0 (base) to 1 (tip).
enum BladeProfile {
    case oval, strap, heart, petal, ray, wide

    func width(_ t: Double) -> Double {
        switch self {
        case .oval:  return pow(sin(.pi * pow(t, 0.75)), 0.9)
        case .strap: return pow(sin(.pi * pow(t, 0.62)), 0.55)
        case .heart: return pow(sin(.pi * pow(t, 0.55)), 0.85)
        case .petal: return pow(sin(min(1, t * 1.02) * .pi * 0.5 + 0.0001), 0.8) * (1 - 0.15 * t)
        case .ray:   return pow(sin(.pi * pow(t, 0.8)), 0.85)
        case .wide:  return pow(sin(min(1, t) * .pi * 0.5), 0.55)
        }
    }
}

struct BladeSpec {
    var length: Double
    var width: Double
    var curl: Double = 0.3        // bends the tip towards local -Z (up, once the blade is tilted outwards)
    var fold: Double = 0.2        // lifts the edges, giving a V cross-section
    var wave: Double = 0          // ripple along the edges
    var notch: Double = 0         // cuts a notch into the tip (cherry blossom petals)
    var profile: BladeProfile = .oval
    var baseColor: UIColor
    var tipColor: UIColor
    var segments: Int = 12        // rows along the length
}

enum PlantGeometry {

    private static func smooth(_ a: Double, _ b: Double, _ x: Double) -> Double {
        let t = min(1, max(0, (x - a) / (b - a)))
        return t * t * (3 - 2 * t)
    }

    /// A curved, folded leaf or petal. The base sits at the origin and the blade grows along +Y.
    /// Same maths as `blade()` in the mockup (8 columns across, `segments` rows along).
    static func blade(_ s: BladeSpec) -> SCNGeometry {
        let cols = 8, rows = max(2, s.segments)
        let c0 = PlantColor.rgba(s.baseColor), c1 = PlantColor.rgba(s.tipColor)
        let white = SIMD4<Float>(1, 1, 1, 1)
        var mesh = PlantMesh()

        for r in 0...rows {
            let t = Double(r) / Double(rows)
            for c in 0...cols {
                let x2 = Double(c) / Double(cols) * 2 - 1          // -1 ... 1 across the blade
                let half = s.profile.width(t) * s.width / 2
                let px = x2 * half
                var py = t * s.length
                let pz = -s.curl * s.length * t * t
                    - abs(px) * s.fold
                    + sin(t * 11) * s.wave * half * abs(x2)
                if s.notch > 0 && t > 0.78 {
                    let n = max(0, 1 - abs(x2) / 0.5)
                    py -= s.notch * s.length * n * n * smooth(0.78, 1, t)
                }
                let k = Float(pow(t, 0.85))
                let rib = Float(max(0, 1 - abs(x2) / 0.08) * 0.12)       // faint pale midrib
                let color = PlantColor.mix(PlantColor.mix(c0, c1, k), white, rib)
                mesh.addVertex(SIMD3<Float>(Float(px), Float(py), Float(pz)), color: color)
            }
        }
        let stride = Int32(cols + 1)
        for r in 0..<rows {
            for c in 0..<cols {
                let a = Int32(r) * stride + Int32(c)
                let b = a + 1, d = a + stride, e = d + 1
                mesh.addTriangle(a, b, d)
                mesh.addTriangle(b, e, d)
            }
        }
        return mesh.makeGeometry()
    }

    // MARK: Surfaces of revolution (pot, stem segments)

    /// Spins a profile of (radius, height) points around the Y axis.
    static func lathe(profile: [SIMD2<Float>], sides: Int = 48, color: UIColor, roughness: CGFloat = 0.8) -> SCNGeometry {
        let rgba = PlantColor.rgba(color)
        var mesh = PlantMesh()
        for p in profile {
            for s in 0...sides {
                let a = Float(s) / Float(sides) * 2 * .pi
                mesh.addVertex(SIMD3<Float>(p.x * sin(a), p.y, p.x * cos(a)), color: rgba)
            }
        }
        let stride = Int32(sides + 1)
        for r in 0..<(profile.count - 1) {
            for s in 0..<sides {
                let a = Int32(r) * stride + Int32(s)
                let b = a + 1, d = a + stride, e = d + 1
                mesh.addTriangle(a, d, b)
                mesh.addTriangle(b, d, e)
            }
        }
        return mesh.makeGeometry(doubleSided: true, roughness: roughness)
    }

    /// The terracotta pot from the mockup: inner profile is hollow, the soil disc is added by the model.
    /// Origin is the centre of the base; the rim top is at y = 1.22 and the soil line at y = 1.1.
    static func pot(color: UIColor = PlantColor.hex(0xc9623a)) -> SCNGeometry {
        let profile: [SIMD2<Float>] = [
            SIMD2(0.0, 0), SIMD2(0.62, 0), SIMD2(0.66, 0.04), SIMD2(0.95, 1.02),
            SIMD2(1.08, 1.04), SIMD2(1.10, 1.16), SIMD2(1.04, 1.22), SIMD2(0.93, 1.18), SIMD2(0.90, 1.10)
        ]
        return lathe(profile: profile, sides: 56, color: color, roughness: 0.82)
    }

    /// A tapered tube from y = 0 up to y = length, used for the stem segments and petioles.
    static func tube(length: Float, bottomRadius: Float, topRadius: Float, sides: Int = 10, color: UIColor) -> SCNGeometry {
        lathe(profile: [SIMD2(bottomRadius, 0), SIMD2(topRadius, length)], sides: sides, color: color, roughness: 0.6)
    }

    // MARK: Seed disc (sunflower centre, daisy centre)

    private static let icoT: Float = (1 + sqrtf(5)) / 2
    private static let icoVerts: [SIMD3<Float>] = {
        let t = icoT
        let raw: [SIMD3<Float>] = [
            SIMD3(-1, t, 0), SIMD3(1, t, 0), SIMD3(-1, -t, 0), SIMD3(1, -t, 0),
            SIMD3(0, -1, t), SIMD3(0, 1, t), SIMD3(0, -1, -t), SIMD3(0, 1, -t),
            SIMD3(t, 0, -1), SIMD3(t, 0, 1), SIMD3(-t, 0, -1), SIMD3(-t, 0, 1)
        ]
        return raw.map { simd_normalize($0) }
    }()
    private static let icoFaces: [[Int32]] = [
        [0, 11, 5], [0, 5, 1], [0, 1, 7], [0, 7, 10], [0, 10, 11],
        [1, 5, 9], [5, 11, 4], [11, 10, 2], [10, 7, 6], [7, 1, 8],
        [3, 9, 4], [3, 4, 2], [3, 2, 6], [3, 6, 8], [3, 8, 9],
        [4, 9, 5], [2, 4, 11], [6, 2, 10], [8, 6, 7], [9, 8, 1]
    ]

    /// Seeds laid out in a golden-angle spiral on a shallow dome, merged into ONE mesh
    /// (SceneKit has no instancing, so hundreds of separate nodes would be slow).
    /// `color(f, i)` gets f = 0 at the centre to 1 at the edge, and the seed index.
    static func seedDisc(count: Int, radius: Float, dome: Float, seedSize: Float, y: Float = 0,
                         color: (_ f: Float, _ i: Int) -> UIColor) -> SCNGeometry {
        var mesh = PlantMesh()
        let goldenAngle = Float.pi * (3 - sqrtf(5))
        for i in 0..<count {
            let f = sqrtf((Float(i) + 0.5) / Float(count))
            let r = f * radius, a = Float(i) * goldenAngle
            let centre = SIMD3<Float>(cosf(a) * r, y + dome * (1 - f * f), sinf(a) * r)
            let size = seedSize * (0.7 + 0.5 * f)
            let rgba = PlantColor.rgba(color(f, i))
            let base = Int32(mesh.positions.count)
            for v in icoVerts {
                // squash a little in Y and turn each seed so they do not all line up
                let sx = v.x * size, sy = v.y * size * 0.8, sz = v.z * size
                let rx = sx * cosf(a) + sz * sinf(a), rz = -sx * sinf(a) + sz * cosf(a)
                mesh.addVertex(centre + SIMD3<Float>(rx, sy, rz), color: rgba)
            }
            for face in icoFaces {
                mesh.addTriangle(base + face[0], base + face[1], base + face[2])
            }
        }
        return mesh.makeGeometry(doubleSided: false, roughness: 0.8)
    }
}
