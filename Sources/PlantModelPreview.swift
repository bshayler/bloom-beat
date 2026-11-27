#if DEBUG
import SwiftUI
import SceneKit

// Xcode preview for step 3: the animated plant model with sliders for flower, growth and wilt.
// Open this file in Xcode and show the canvas (Editor > Canvas). Drag in the scene to orbit.
// Compare with Design/plant-studio-reference.html (same flowers, stages and wilt).

private struct PlantModelPreviewView: View {
    @State private var stage = PlantScene()
    @State private var health = 0.93
    @State private var wilt = 0.0
    @State private var flower = 3

    private func refresh() {
        stage.model.update(health: health, wilt: wilt, time: 0, pop: 0, flower: flower)
    }

    var body: some View {
        VStack(spacing: 10) {
            SceneView(scene: stage.scene, pointOfView: stage.cameraNode,
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
        .onAppear { stage.frame(for: CGSize(width: 390, height: 420)); refresh() }
        .onChange(of: health) { refresh() }
        .onChange(of: wilt) { refresh() }
        .onChange(of: flower) { refresh() }
    }
}

#Preview("Plant model") {
    PlantModelPreviewView()
}
#endif
