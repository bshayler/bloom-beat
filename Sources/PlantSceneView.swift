import SwiftUI
import SceneKit
import UIKit

// MARK: - SwiftUI host for the 3D plant (step 4 of the SceneKit port)

/// Flip `enabled` to false to fall back to the 2D Canvas plants everywhere (for A/B checks and as a safety net).
enum PlantRendering {
    static var enabled = true

    /// What the views actually check. 3D is skipped in Low Power Mode, or when the app is launched with
    /// `-no3dplants` (handy for comparing frame rates in Instruments).
    static var effective: Bool {
        enabled
            && !ProcessInfo.processInfo.isLowPowerModeEnabled
            && !CommandLine.arguments.contains("-no3dplants")
    }
}

/// One frame of plant state, supplied by the game each frame.
struct PlantFrame {
    var health: Double
    var wilt: Double
    var flower: Int
    var pop: Double
}

/// One SceneKit scene with a pot, a plant model, lights and a camera. Reused by the live view and the Xcode preview.
final class PlantScene {
    let scene = SCNScene()
    let model = PlantModel()
    let cameraNode = SCNNode()
    private let target = SCNNode()

    init() {
        scene.background.contents = UIColor.clear
        scene.rootNode.addChildNode(model.root)

        // shadow catcher under the pot
        let floor = SCNFloor()
        floor.reflectivity = 0
        let floorMaterial = SCNMaterial()
        floorMaterial.lightingModel = .shadowOnly
        floor.materials = [floorMaterial]
        scene.rootNode.addChildNode(SCNNode(geometry: floor))

        let sun = SCNNode()
        let sunLight = SCNLight()
        sunLight.type = .directional
        sunLight.intensity = 1700
        sunLight.castsShadow = true
        sunLight.shadowRadius = 6
        sunLight.shadowMapSize = CGSize(width: 1024, height: 1024)
        sunLight.shadowSampleCount = 8
        sunLight.shadowColor = UIColor(white: 0, alpha: 0.35)
        sun.light = sunLight
        sun.eulerAngles = SCNVector3(-0.95, 0.75, 0)
        scene.rootNode.addChildNode(sun)

        let ambient = SCNNode()
        let ambientLight = SCNLight()
        ambientLight.type = .ambient
        ambientLight.intensity = 550
        ambient.light = ambientLight
        scene.rootNode.addChildNode(ambient)

        target.position = SCNVector3(0, Self.targetY, 0)
        scene.rootNode.addChildNode(target)
        let camera = SCNCamera()
        camera.fieldOfView = 34          // vertical
        camera.zNear = 0.5
        camera.zFar = 60
        cameraNode.camera = camera
        let look = SCNLookAtConstraint(target: target)
        look.isGimbalLockEnabled = true
        cameraNode.constraints = [look]
        scene.rootNode.addChildNode(cameraNode)
        frame(for: CGSize(width: 1, height: 1))
    }

    private static let targetY: Float = 2.45
    /// Height and half-width, in scene units, that the biggest plant (a sunflower) needs to stay in view.
    private static let neededHeight: Float = 5.9
    private static let neededWidth: Float = 3.6

    /// Places the camera so the whole plant fits in a view of this size, tall or wide.
    func frame(for size: CGSize) {
        let aspect = Float(max(1, size.width) / max(1, size.height))
        let tanHalf = tanf(34 * .pi / 180 / 2)
        let forHeight = Self.neededHeight / (2 * tanHalf)
        let forWidth = Self.neededWidth / (2 * tanHalf * aspect)
        let distance = max(forHeight, forWidth)
        let elevation: Float = 0.17
        cameraNode.position = SCNVector3(0, Self.targetY + distance * sinf(elevation), distance * cosf(elevation))
    }
}

/// SCNView that reports its size so the camera can be re-framed when the layout changes.
final class PlantSCNView: SCNView {
    var onLayout: ((CGSize) -> Void)?

    override func layoutSubviews() {
        super.layoutSubviews()
        onLayout?(bounds.size)
    }
}

/// The 3D plant as a SwiftUI view. It takes the same inputs as the 2D `PlantPreview`.
struct PlantSceneView: UIViewRepresentable {
    var health: Double
    var wilt: Double
    var flower: Int
    var cycle = false          // menu demo: grows through every flower on its own, like the 2D version
    var live: (() -> PlantFrame)? = nil      // in-game: read fresh values from the engine every frame
    var framesPerSecond = 60               // the plant changes slowly, so the game uses 30 to save battery
    var antialiasing: SCNAntialiasingMode = .multisampling4X

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> PlantSCNView {
        let coordinator = context.coordinator
        let view = PlantSCNView(frame: .zero)
        view.scene = coordinator.plant.scene
        view.pointOfView = coordinator.plant.cameraNode
        view.delegate = coordinator
        view.backgroundColor = .clear
        view.isOpaque = false
        view.antialiasingMode = antialiasing
        view.preferredFramesPerSecond = framesPerSecond
        view.isPlaying = true            // keeps rendering so the delegate runs every frame
        view.allowsCameraControl = false
        view.isUserInteractionEnabled = false
        view.onLayout = { [weak coordinator] size in coordinator?.plant.frame(for: size) }
        coordinator.set(health: health, wilt: wilt, flower: flower, cycle: cycle, live: live)
        return view
    }

    func updateUIView(_ view: PlantSCNView, context: Context) {
        context.coordinator.set(health: health, wilt: wilt, flower: flower, cycle: cycle, live: live)
    }

    final class Coordinator: NSObject, SCNSceneRendererDelegate {
        let plant = PlantScene()
        private let lock = NSLock()
        private var health = 0.5, wilt = 0.0, flower = 3, cycle = false
        private var live: (() -> PlantFrame)?

        func set(health: Double, wilt: Double, flower: Int, cycle: Bool, live: (() -> PlantFrame)?) {
            lock.lock()
            self.live = live
            self.health = health
            self.wilt = wilt
            self.flower = flower
            self.cycle = cycle
            lock.unlock()
        }

        // Runs on SceneKit's render thread once per frame: the right place to change the scene.
        func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
            lock.lock()
            var h = health
            let w = wilt
            var fl = flower
            let cycling = cycle
            let provider = live
            lock.unlock()

            let t = Date().timeIntervalSinceReferenceDate
            var pop = 0.0
            if cycling {
                // same cycle as the 2D PlantPreview: 16 s per flower, growing seedling to big bloom
                let period = 16.0
                fl = 3 + Int(t / period) % 4
                let phase = t.truncatingRemainder(dividingBy: period) / period
                h = 0.08 + 0.92 * min(1, phase / 0.9)
                let stage = PlantStage.index(for: h)
                let stageStart = PlantStage.thresholds[stage]
                pop = exp(-(h - stageStart) * 40) * (stage > 0 ? 1 : 0)
            }
            if let provider {
                // in-game: the engine's own values, read once per frame (plain numbers, so a stale read is harmless)
                let f = provider()
                plant.model.update(health: f.health, wilt: f.wilt, time: t, pop: f.pop, flower: f.flower)
                return
            }
            plant.model.update(health: h, wilt: w, time: t, pop: pop, flower: fl)
        }
    }
}
