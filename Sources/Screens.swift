import SwiftUI

private let ink = RGB(0.10, 0.32, 0.20).color
private let leaf = RGB(0.28, 0.64, 0.32)

struct ContentView: View {
    @StateObject private var engine = GameEngine()

    var body: some View {
        ZStack {
            switch engine.phase {
            case .menu, .loading:
                MenuView(engine: engine)
            case .playing, .paused:
                GameView(engine: engine)
            case .finished:
                ResultView(engine: engine)
            }
            if engine.phase == .loading {
                ZStack {
                    Color.black.opacity(0.35).ignoresSafeArea()
                    VStack(spacing: 12) {
                        ProgressView().controlSize(.large).tint(.white)
                        Text("Planting seeds…").font(.system(.headline, design: .rounded)).foregroundStyle(.white)
                    }
                    .padding(28)
                    .background(RoundedRectangle(cornerRadius: 22).fill(ink.opacity(0.92)))
                }
            }
            if engine.phase == .paused {
                ZStack {
                    Color.black.opacity(0.5).ignoresSafeArea()
                    VStack(spacing: 14) {
                        Text("Paused").font(.system(size: 36, weight: .heavy, design: .rounded)).foregroundStyle(.white)
                        Button("Resume") { engine.resume() }.buttonStyle(BigButton())
                        Button("Quit to menu") { engine.quit() }.buttonStyle(BigButton(secondary: true))
                    }
                    .padding(.horizontal, 50)
                }
            }
        }
    }
}

struct BigButton: ButtonStyle {
    var secondary = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 20, weight: .heavy, design: .rounded))
            .foregroundStyle(secondary ? ink : .white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                Capsule().fill(secondary
                    ? LinearGradient(colors: [.white, Color.white.opacity(0.82)], startPoint: .top, endPoint: .bottom)
                    : LinearGradient(colors: [leaf.mixed(RGB(1, 1, 1), 0.25).color, leaf.mixed(RGB(0, 0, 0), 0.12).color], startPoint: .top, endPoint: .bottom))
            )
            .overlay(Capsule().stroke(.white.opacity(secondary ? 0.0 : 0.5), lineWidth: 1.5))
            .shadow(color: .black.opacity(0.25), radius: 8, y: 4)
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
    }
}

private struct Glass: ViewModifier {
    var selected = false
    func body(content: Content) -> some View {
        content
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 18).fill(.white.opacity(selected ? 0.92 : 0.55)))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(selected ? leaf.color : .white.opacity(0.7), lineWidth: selected ? 3 : 1))
            .shadow(color: .black.opacity(selected ? 0.18 : 0.08), radius: selected ? 8 : 4, y: 3)
    }
}

struct MenuView: View {
    @ObservedObject var engine: GameEngine

    var body: some View {
        ZStack {
            SceneryBackground()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    VStack(spacing: 2) {
                        Text("Seedling Symphony")
                            .font(.system(size: 34, weight: .heavy, design: .rounded))
                            .foregroundStyle(LinearGradient(colors: [RGB(0.98, 0.98, 0.9).color, RGB(0.80, 0.97, 0.75).color],
                                                            startPoint: .top, endPoint: .bottom))
                            .shadow(color: ink.opacity(0.65), radius: 0, x: 0, y: 3)
                            .shadow(color: .black.opacity(0.25), radius: 8, y: 6)
                        Text("Grow a garden with rhythm")
                            .font(.system(size: 15, weight: .semibold, design: .rounded)).foregroundStyle(.white)
                            .shadow(color: ink.opacity(0.6), radius: 2, y: 1)
                    }
                    .padding(.top, 6)

                    PlantPreview(cycle: true).frame(height: 250)

                    sectionTitle("Pick a song")
                    VStack(spacing: 8) {
                        ForEach(Array(engine.songs.enumerated()), id: \.offset) { idx, s in songRow(idx, s) }
                    }

                    sectionTitle("Number of tracks")
                    HStack(spacing: 8) {
                        ForEach(Difficulty.allCases) { d in diffButton(d) }
                    }

                    HStack(spacing: 14) {
                        tip("hand.tap.fill", "Tap")
                        tip("arrow.up.to.line", "Hold vines")
                        tip("circle.grid.2x1.fill", "Chords")
                    }
                    .padding(.top, 2)

                    Button("Plant & Play") { engine.start() }
                        .buttonStyle(BigButton())
                        .disabled(engine.phase == .loading)

                    Text("Songs are public-domain compositions played by an in-app synthesizer, so everything is royalty free.")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.9)).multilineTextAlignment(.center)
                        .shadow(color: ink.opacity(0.6), radius: 2, y: 1)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
        }
    }

    func tip(_ icon: String, _ label: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
            Text(label)
        }
        .font(.system(size: 12, weight: .bold, design: .rounded))
        .foregroundStyle(ink)
        .padding(.horizontal, 12).padding(.vertical, 7)
        .background(Capsule().fill(.white.opacity(0.7)))
    }

    func sectionTitle(_ s: String) -> some View {
        Text(s.uppercased()).font(.system(size: 12, weight: .heavy, design: .rounded))
            .foregroundStyle(.white).shadow(color: ink.opacity(0.7), radius: 2, y: 1)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    func songRow(_ idx: Int, _ s: SongSpec) -> some View {
        let sel = engine.selectedSong == idx
        let best = engine.best(s, engine.difficulty.lanes)
        return Button { engine.selectedSong = idx } label: {
            HStack(spacing: 12) {
                Text(s.emoji).font(.system(size: 30))
                VStack(alignment: .leading, spacing: 1) {
                    Text(s.title).font(.system(size: 16, weight: .bold, design: .rounded)).foregroundStyle(ink)
                        .lineLimit(1).minimumScaleFactor(0.8)
                    Text("\(s.blurb) · \(Int(s.bpm)) BPM").font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(ink.opacity(0.65)).lineLimit(1).minimumScaleFactor(0.8)
                }
                Spacer(minLength: 4)
                if best > 0 {
                    VStack(alignment: .trailing, spacing: 0) {
                        Text("BEST").font(.system(size: 9, weight: .heavy)).foregroundStyle(ink.opacity(0.5))
                        Text("\(best)").font(.system(size: 14, weight: .bold, design: .rounded)).foregroundStyle(ink)
                    }
                }
            }
            .modifier(Glass(selected: sel))
        }
        .buttonStyle(.plain)
    }

    func diffButton(_ d: Difficulty) -> some View {
        let sel = engine.difficulty == d
        return Button { engine.difficulty = d } label: {
            VStack(spacing: 4) {
                Text("\(d.lanes)").font(.system(size: 28, weight: .heavy, design: .rounded))
                HStack(spacing: 2) {
                    ForEach(0..<d.lanes, id: \.self) { i in
                        Circle().fill(Palette.laneColor(i, of: d.lanes).color).frame(width: 6, height: 6)
                            .overlay(Circle().stroke(.white.opacity(0.8), lineWidth: 0.5))
                    }
                }
                Text(d.name).font(.system(size: 12, weight: .heavy, design: .rounded))
            }
            .foregroundStyle(sel ? .white : ink)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: 18)
                .fill(sel ? LinearGradient(colors: [leaf.mixed(RGB(1, 1, 1), 0.2).color, leaf.mixed(RGB(0, 0, 0), 0.12).color], startPoint: .top, endPoint: .bottom)
                          : LinearGradient(colors: [.white.opacity(0.6), .white.opacity(0.5)], startPoint: .top, endPoint: .bottom)))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(.white.opacity(sel ? 0.6 : 0.7), lineWidth: 1))
            .shadow(color: .black.opacity(sel ? 0.2 : 0.06), radius: sel ? 6 : 3, y: 2)
        }
        .buttonStyle(.plain)
    }
}

struct ResultView: View {
    @ObservedObject var engine: GameEngine

    var body: some View {
        let h = engine.health
        let wilted = engine.displayWilt > 0.5
        let name = PlantStage.names[PlantStage.index(for: h)]
        ZStack {
            SceneryBackground()
            VStack(spacing: 12) {
                Text("Song complete").font(.system(size: 30, weight: .heavy, design: .rounded)).foregroundStyle(.white)
                    .shadow(color: ink.opacity(0.7), radius: 0, y: 2)
                PlantPreview(health: h, wilt: engine.displayWilt).frame(height: 270)
                Text(wilted ? "Your \(name.lowercased()) is wilting…" : "Your garden grew a \(name)!")
                    .font(.system(size: 20, weight: .bold, design: .rounded)).foregroundStyle(.white)
                    .shadow(color: ink.opacity(0.7), radius: 2, y: 1)
                    .multilineTextAlignment(.center)

                HStack(spacing: 18) {
                    VStack {
                        Text(engine.grade).font(.system(size: 64, weight: .heavy, design: .rounded)).foregroundStyle(ink)
                        Text("GRADE").font(.caption2.weight(.heavy)).foregroundStyle(ink.opacity(0.6))
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Score \(engine.score)").font(.system(size: 20, weight: .heavy, design: .rounded))
                        Text("Max combo \(engine.maxCombo)")
                        Text("Perfect \(engine.counts[0]) · Great \(engine.counts[1])")
                        Text("Good \(engine.counts[2]) · Miss \(engine.counts[3])")
                    }
                    .font(.system(size: 14, weight: .semibold, design: .rounded)).foregroundStyle(ink)
                }
                .padding(16)
                .background(RoundedRectangle(cornerRadius: 22).fill(.white.opacity(0.85)))
                .shadow(color: .black.opacity(0.15), radius: 8, y: 4)

                Spacer(minLength: 4)
                Button("Play again") { engine.phase = .menu; engine.start() }.buttonStyle(BigButton())
                Button("Back to menu") { engine.phase = .menu }.buttonStyle(BigButton(secondary: true))
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 20)
        }
    }
}
