import SwiftUI
import SceneKit
import Metal
import UIKit

// MARK: - Cached still images of the 3D plants (step 5 of the SceneKit port)
//
// The shelf shows many plants at once. A live SCNView per cell would be far too heavy, so each plant is
// rendered ONCE to an image by a shared offscreen SCNRenderer and kept in a cache. All SceneKit work for
// snapshots happens on one private serial queue.

enum PlantSnapshots {
    struct Key: Hashable {
        let flower: Int
        let health: Int      // health in 1/50 steps
        let wilt: Int        // wilt in 1/10 steps
        let width: Int       // points
        let height: Int      // points
        let scale: Int       // screen scale x10

        var id: NSString { "\(flower)-\(health)-\(wilt)-\(width)x\(height)@\(scale)" as NSString }
    }

    static func key(health: Double, wilt: Double, flower: Int, size: CGSize, scale: CGFloat) -> Key {
        Key(flower: flower,
            health: Int((min(1, max(0, health)) * 50).rounded()),
            wilt: Int((min(1, max(0, wilt)) * 10).rounded()),
            width: Int(size.width.rounded()),
            height: Int(size.height.rounded()),
            scale: Int((scale * 10).rounded()))
    }

    private static let cache: NSCache<NSString, UIImage> = {
        let c = NSCache<NSString, UIImage>()
        c.countLimit = 120
        return c
    }()

    static func cached(_ key: Key) -> UIImage? { cache.object(forKey: key.id) }

    // Only touched on `queue`.
    private static let queue = DispatchQueue(label: "bloombeat.plant-snapshots", qos: .userInitiated)
    private static var plantScene: PlantScene?
    private static var renderer: SCNRenderer?

    /// Renders (or returns the cached) image for this key. The plant is drawn at the bucketed health and wilt
    /// so the cache stays consistent.
    static func image(for key: Key) async -> UIImage? {
        if let hit = cached(key) { return hit }
        let image: UIImage? = await withCheckedContinuation { continuation in
            queue.async { continuation.resume(returning: renderSync(key)) }
        }
        if let image { cache.setObject(image, forKey: key.id) }
        return image
    }

    private static func renderSync(_ key: Key) -> UIImage? {
        guard key.width > 0, key.height > 0 else { return nil }
        let plant: PlantScene
        if let existing = plantScene {
            plant = existing
        } else {
            plant = PlantScene()
            plantScene = plant
        }
        let sceneRenderer: SCNRenderer
        if let existing = renderer {
            sceneRenderer = existing
        } else {
            sceneRenderer = SCNRenderer(device: MTLCreateSystemDefaultDevice(), options: nil)
            sceneRenderer.scene = plant.scene
            sceneRenderer.pointOfView = plant.cameraNode
            renderer = sceneRenderer
        }

        let scale = CGFloat(key.scale) / 10
        plant.frame(for: CGSize(width: key.width, height: key.height))
        plant.model.update(health: Double(key.health) / 50, wilt: Double(key.wilt) / 10, time: 0, pop: 0, flower: key.flower)

        let pixels = CGSize(width: CGFloat(key.width) * scale, height: CGFloat(key.height) * scale)
        let snapshot = sceneRenderer.snapshot(atTime: 0, with: pixels, antialiasingMode: .multisampling4X)
        guard let cg = snapshot.cgImage else { return nil }
        return UIImage(cgImage: cg, scale: scale, orientation: .up)
    }
}

/// A still picture of the 3D plant, for lists and grids. Shows nothing for a moment on first appearance,
/// then the cached image on every later one.
struct PlantSnapshotView: View {
    var health: Double
    var wilt: Double
    var flower: Int

    @Environment(\.displayScale) private var displayScale
    @State private var rendered: (key: PlantSnapshots.Key, image: UIImage)?

    var body: some View {
        GeometryReader { geo in
            let key = PlantSnapshots.key(health: health, wilt: wilt, flower: flower, size: geo.size, scale: displayScale)
            ZStack {
                if let image = PlantSnapshots.cached(key) ?? (rendered?.key == key ? rendered?.image : nil) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .task(id: key) {
                if PlantSnapshots.cached(key) != nil { return }
                if let image = await PlantSnapshots.image(for: key) {
                    rendered = (key, image)
                }
            }
        }
    }
}
