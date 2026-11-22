import SwiftUI

struct RGB {
    var r: Double, g: Double, b: Double
    init(_ r: Double, _ g: Double, _ b: Double) { self.r = r; self.g = g; self.b = b }
    func mixed(_ o: RGB, _ t: Double) -> RGB {
        let k = max(0, min(1, t))
        return RGB(r + (o.r - r) * k, g + (o.g - g) * k, b + (o.b - b) * k)
    }
    var color: Color { Color(red: r, green: g, blue: b) }
}

func smooth(_ a: Double, _ b: Double, _ x: Double) -> Double {
    let t = max(0, min(1, (x - a) / (b - a)))
    return t * t * (3 - 2 * t)
}

enum Difficulty: Int, CaseIterable, Identifiable {
    case two = 2, three = 3, four = 4, five = 5
    var id: Int { rawValue }
    var lanes: Int { rawValue }
    var name: String {
        switch self {
        case .two: return "Seedling"
        case .three: return "Sprout"
        case .four: return "Bloom"
        case .five: return "Garden"
        }
    }
    /// seconds a note takes to fall from the top to the hit zone
    var approach: Double {
        switch self {
        case .two: return 2.1
        case .three: return 1.9
        case .four: return 1.7
        case .five: return 1.55
        }
    }
}

enum Palette {
    static let lane: [RGB] = [
        RGB(0.95, 0.45, 0.62),  // rose
        RGB(0.98, 0.72, 0.22),  // marigold
        RGB(0.45, 0.80, 0.40),  // leaf
        RGB(0.35, 0.68, 0.95),  // bluebell
        RGB(0.70, 0.52, 0.92)   // lavender
    ]
    static func laneColor(_ i: Int, of n: Int) -> RGB {
        let maps: [Int: [Int]] = [2: [0, 3], 3: [0, 2, 3], 4: [0, 1, 2, 3], 5: [0, 1, 2, 3, 4]]
        let m = maps[n] ?? [0, 1, 2, 3, 4]
        return lane[m[min(i, m.count - 1)]]
    }
}

enum Judgment: Int {
    case perfect, great, good, miss
    var label: String {
        switch self {
        case .perfect: return "Perfect!"
        case .great: return "Great"
        case .good: return "Good"
        case .miss: return "Miss"
        }
    }
    var color: RGB {
        switch self {
        case .perfect: return RGB(1.0, 0.85, 0.25)
        case .great: return RGB(0.55, 0.95, 0.55)
        case .good: return RGB(0.55, 0.85, 1.0)
        case .miss: return RGB(0.95, 0.40, 0.35)
        }
    }
}

enum PlantStage {
    static let names = ["Seedling", "Sprout", "Bud", "Daisy", "Tulip", "Cherry Blossom", "Sunflower"]
    static let thresholds: [Double] = [0, 0.18, 0.34, 0.50, 0.66, 0.80, 0.92]
    static func index(for h: Double) -> Int {
        var idx = 0
        for (i, t) in thresholds.enumerated() where h >= t { idx = i }
        return idx
    }
}

struct PlantRecord: Codable, Identifiable {
    var id = UUID()
    var songID: String
    var lanes: Int
    var health: Double
    var wilt: Double
    var score: Int
    var grade: String
    var maxCombo: Int
    var date: Date

    var song: SongSpec? { SongSpec.all.first { $0.id == songID } }
    var stageName: String { PlantStage.names[PlantStage.index(for: health)] }
    var isWilted: Bool { wilt > 0.5 }
}
