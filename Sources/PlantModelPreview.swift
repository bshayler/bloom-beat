#if DEBUG
import SwiftUI
import SceneKit

// Xcode preview for step 3: the animated plant model with sliders for flower, growth and wilt.
// Open this file in Xcode and show the canvas (Editor > Canvas). Drag in the scene to orbit.
// Compare with Design/plant-studio-reference.html (same flowers, stages and wilt).

private final class PlantPreviewStage: ObservableObject {
    let scene = SCNScene()
    let model = PlantModel()
    let camera = SCNNode()

    init() {
        scene.background.contents = UIColor(red: 0.84, green: 0.92, blue: 0.80, alpha: 1)
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

        let target = SCNNode()
        target.position = SCNVector3(0, 2.4, 0)
        scene.rootNode.addChildNode(target)
        camera.camera = SCNCamera()
        camera.camera?.fieldOfView = 34
        camera.position = SCNVector3(0, 3.4, 11)
        let look = SCNLookAtConstraint(target: target)
        look.isGimbalLockEnabled = true
        camera.constraints = [look]
        scene.rootNode.addChildNode(camera)
    }

    func refresh(health: Double, wilt: Double, flower: Int) {
        model.update(health: health, wilt: wilt, time: 0, pop: 0, flower: flower)
    }
}

private struct PlantModelPreviewView: View {
    @StateObject private var stage = PlantPreviewStage()
    @State private var health = 0.93
    @State private var wilt = 0.0
    @State private var flower = 3

    var body: some View {
        VStack(spacing: 10) {
            SceneView(scene: stage.scene, pointOfView: stage.camera,
                      options: [.allowsCameraControl, .rendersContinuously], antialiasingMode: .multisampling4X)
                .frame(height: 420)
            Picker("Flower", selection: $flower) {
                Text("Daisy").tag(3)
                Text("Tulip").tag(4)
                Text("Cherry").tag(5)
                Text("Sunflower").tag(6)
            }
            .pickerStyle(.segmented)
            Text("Growth \(Int(health * 100))%  ·  \(PlantStage.name(PlantStage.index(for: health), flower: flower))")
                .font(.caption)
            Slider(value: $health, in: 0...0.999)
            Text("Wilt \(Int(wilt * 100))%").font(.caption)
            Slider(value: $wilt, in: 0...1)
        }
        .padding()
        .onAppear { stage.refresh(health: health, wilt: wilt, flower: flower) }
        .onChange(of: health) { stage.refresh(health: health, wilt: wilt, flower: flower) }
        .onChange(of: wilt) { stage.refresh(health: health, wilt: wilt, flower: flower) }
        .onChange(of: flower) { stage.refresh(health: health, wilt: wilt, flower: flower) }
    }
}

#Preview("Plant model") {
    PlantModelPreviewView()
}
#endif
