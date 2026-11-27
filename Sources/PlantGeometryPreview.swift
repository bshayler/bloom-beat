#if DEBUG
import SwiftUI
import SceneKit

// Xcode preview for step 2: shows the raw shapes from PlantGeometry so they can be checked against
// Design/plant-studio-reference.html before the plant model is built on top of them.
// Open this file in Xcode and use the canvas (Editor > Canvas). Drag to orbit, pinch to zoom.

private func makePreviewScene() -> SCNScene {
    let scene = SCNScene()
    scene.background.contents = UIColor(red: 0.84, green: 0.92, blue: 0.80, alpha: 1)

    func place(_ geometry: SCNGeometry, x: Float, y: Float = 0, tiltX: Float = 0) {
        let node = SCNNode(geometry: geometry)
        node.position = SCNVector3(x, y, 0)
        node.eulerAngles.x = tiltX
        scene.rootNode.addChildNode(node)
    }

    // pot
    place(PlantGeometry.pot(), x: -4)

    // one leaf and one petal of each profile, tilted outwards so the curl reads
    let green0 = PlantColor.hex(0x2b7330), green1 = PlantColor.hex(0x7dc243)
    let profiles: [(BladeProfile, Double, Double)] = [
        (.oval, 1.0, 0.5), (.strap, 1.6, 0.42), (.heart, 1.0, 0.95)
    ]
    for (i, p) in profiles.enumerated() {
        let spec = BladeSpec(length: p.1, width: p.2, curl: 0.35, fold: 0.18, profile: p.0,
                             baseColor: green0, tipColor: green1)
        place(PlantGeometry.blade(spec), x: -1.5 + Float(i) * 1.4, tiltX: 0.7)
    }
    let petal = BladeSpec(length: 0.85, width: 0.78, curl: 0.32, fold: 0.16, notch: 0.14, profile: .wide,
                          baseColor: PlantColor.hex(0xee5a8c), tipColor: PlantColor.hex(0xffe6ef))
    place(PlantGeometry.blade(petal), x: 2.8, tiltX: 0.98)

    // seed disc, like the sunflower centre
    let disc = PlantGeometry.seedDisc(count: 520, radius: 0.64, dome: 0.14, seedSize: 0.034, y: 0.05) { f, i in
        f < 0.25 ? PlantColor.hex(0x2a170a)
            : f < 0.8 ? (i % 2 == 0 ? PlantColor.hex(0x4b2a12) : PlantColor.hex(0x3a2010))
            : (i % 2 == 0 ? PlantColor.hex(0x8a5a1e) : PlantColor.hex(0xb5841f))
    }
    place(disc, x: 4.4, y: 0.4, tiltX: -0.5)

    // simple key light plus fill, like the mockup
    let sun = SCNNode()
    sun.light = SCNLight()
    sun.light?.type = .directional
    sun.light?.intensity = 1600
    sun.light?.castsShadow = true
    sun.eulerAngles = SCNVector3(-0.9, 0.7, 0)
    scene.rootNode.addChildNode(sun)
    let fill = SCNNode()
    fill.light = SCNLight()
    fill.light?.type = .ambient
    fill.light?.intensity = 500
    scene.rootNode.addChildNode(fill)

    let camera = SCNNode()
    camera.camera = SCNCamera()
    camera.position = SCNVector3(0.3, 2.2, 10)
    scene.rootNode.addChildNode(camera)
    return scene
}

#Preview("Plant geometry") {
    SceneView(scene: makePreviewScene(), options: [.allowsCameraControl])
        .frame(height: 420)
}
#endif
