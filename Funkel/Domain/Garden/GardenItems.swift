import Foundation

// Pips Garten, which grows into a little farm over days and weeks: the
// catalogue of everything a child can put on it. A port of
// web/src/domain/garden.ts; ids, prices, levels and timings are the same, so
// a farm moves between the web app and this app unchanged.

enum GardenCategory: String, CaseIterable, Identifiable {
    case plants, animals, buildings, paths, decor
    var id: String { rawValue }

    var icon: String {
        switch self {
        case .plants: "🌱"
        case .animals: "🐾"
        case .buildings: "🏠"
        case .paths: "🛤️"
        case .decor: "✨"
        }
    }
}

/// What the farm makes: collected, kept in the store, sold or delivered.
enum Produce: String, CaseIterable, Codable {
    case egg, milk, wheat, veg, apple, honey

    var emoji: String {
        switch self {
        case .egg: "🥚"
        case .milk: "🥛"
        case .wheat: "🌾"
        case .veg: "🥕"
        case .apple: "🍎"
        case .honey: "🍯"
        }
    }
}

/// Animals that need a home, by the kind of home.
enum HomeGroup: String {
    case dog, cat, chicken, farm, duck
}

struct GardenItem: Identifiable, Equatable {
    let id: String
    let price: Int
    let category: GardenCategory
    /// Farm level that unlocks it.
    let level: Int
    /// Picture per stage (emoji, or "art:<id>" for a drawn one); the last one may be a variant.
    let stages: [String]
    /// Days after placing when each stage starts (same length as stages).
    let days: [Int]
    var variants: [String]? = nil
    /// Columns × rows on the grid.
    var width = 1
    var height = 1
    /// A building: which animals live here, and how many.
    var houses: HomeGroup? = nil
    var capacity = 0
    /// An animal that needs a finished home of this kind.
    var needs: HomeGroup? = nil
    /// Grown, it gives this once a day (hens, cows, bees, apple trees).
    var produce: Produce? = nil
    /// A crop: grown, it can be harvested, and then grows again.
    var harvest: Produce? = nil
    /// Roads, paths and fences join up with neighbours of the same kind.
    var connects = false

    /// What the shop shows: the finished look.
    var shopPicture: String { variants?.first ?? stages[stages.count - 1] }

    /// The kind of thing this is on the meadow (decides how it is drawn and moves).
    var isCrop: Bool { harvest != nil || id == "flower" }
}

enum GardenCatalog {
    static let building = "🚧"

    static let items: [GardenItem] = [
        // Plants
        GardenItem(id: "flower", price: 3, category: .plants, level: 1, stages: ["🌱", "🌿", "🌷"], days: [0, 1, 3], variants: ["🌷", "🌻", "🌼", "🌸", "🌹", "🪻"]),
        GardenItem(id: "wheat", price: 3, category: .plants, level: 1, stages: ["🌱", "🌾"], days: [0, 1], harvest: .wheat),
        GardenItem(id: "mushroom", price: 2, category: .plants, level: 1, stages: ["🍄"], days: [0]),
        GardenItem(id: "tree", price: 12, category: .plants, level: 1, stages: ["🌱", "🪴", "🌳"], days: [0, 3, 7], variants: ["🌳", "🌲"]),
        GardenItem(id: "vegetable", price: 4, category: .plants, level: 2, stages: ["🌱", "🌿", "🥕"], days: [0, 1, 2], variants: ["🥕", "🥬", "🎃", "🍅", "🥔"], harvest: .veg),
        GardenItem(id: "appletree", price: 20, category: .plants, level: 4, stages: ["🌱", "🪴", "🌳"], days: [0, 2, 4], produce: .apple),
        // Animals: small ones live anywhere; farm animals need their home first.
        GardenItem(id: "snail", price: 4, category: .animals, level: 1, stages: ["🐌"], days: [0]),
        GardenItem(id: "ladybug", price: 5, category: .animals, level: 1, stages: ["🐞"], days: [0]),
        GardenItem(id: "butterfly", price: 6, category: .animals, level: 1, stages: ["🦋"], days: [0]),
        GardenItem(id: "bee", price: 6, category: .animals, level: 1, stages: ["🐝"], days: [0]),
        GardenItem(id: "rabbit", price: 8, category: .animals, level: 2, stages: ["🐇"], days: [0]),
        GardenItem(id: "dog", price: 15, category: .animals, level: 2, stages: ["🐕"], days: [0], needs: .dog),
        GardenItem(id: "chick", price: 6, category: .animals, level: 2, stages: ["🐣", "🐥", "🐔"], days: [0, 2, 4], needs: .chicken, produce: .egg),
        GardenItem(id: "duck", price: 8, category: .animals, level: 3, stages: ["🦆"], days: [0], needs: .duck),
        GardenItem(id: "cat", price: 12, category: .animals, level: 3, stages: ["🐈"], days: [0], needs: .cat),
        GardenItem(id: "sheep", price: 15, category: .animals, level: 4, stages: ["🐑"], days: [0], needs: .farm),
        GardenItem(id: "goat", price: 15, category: .animals, level: 4, stages: ["🐐"], days: [0], needs: .farm),
        GardenItem(id: "pig", price: 18, category: .animals, level: 5, stages: ["🐖"], days: [0], needs: .farm),
        GardenItem(id: "cow", price: 25, category: .animals, level: 5, stages: ["🐄"], days: [0], needs: .farm, produce: .milk),
        GardenItem(id: "horse", price: 30, category: .animals, level: 6, stages: ["🐴"], days: [0], needs: .farm),
        // Buildings take a few days to build.
        GardenItem(id: "doghouse", price: 15, category: .buildings, level: 2, stages: [building, "art:doghouse"], days: [0, 1], houses: .dog, capacity: 1),
        GardenItem(id: "coop", price: 20, category: .buildings, level: 2, stages: [building, "art:coop"], days: [0, 1], houses: .chicken, capacity: 4),
        GardenItem(id: "house", price: 30, category: .buildings, level: 3, stages: ["🏡"], days: [0], houses: .cat, capacity: 2),
        GardenItem(id: "pond", price: 25, category: .buildings, level: 3, stages: [building, "art:pond"], days: [0, 1], width: 2, houses: .duck, capacity: 3),
        GardenItem(id: "barn", price: 40, category: .buildings, level: 4, stages: [building, "art:barn"], days: [0, 2], width: 2, height: 2, houses: .farm, capacity: 4),
        GardenItem(id: "beehive", price: 25, category: .buildings, level: 5, stages: [building, "art:beehive"], days: [0, 1], produce: .honey),
        GardenItem(id: "farmhouse", price: 60, category: .buildings, level: 6, stages: [building, "art:farmhouse"], days: [0, 3], width: 2, height: 2, houses: .cat, capacity: 2),
        GardenItem(id: "windmill", price: 50, category: .buildings, level: 7, stages: [building, "art:windmill"], days: [0, 2], height: 2),
        // Roads, paths and fences are free, so children can lay out their farm.
        GardenItem(id: "road", price: 0, category: .paths, level: 1, stages: ["art:road"], days: [0], connects: true),
        GardenItem(id: "path", price: 0, category: .paths, level: 1, stages: ["art:path"], days: [0], connects: true),
        GardenItem(id: "fence", price: 0, category: .paths, level: 1, stages: ["art:fence"], days: [0], connects: true),
        // Decorations
        GardenItem(id: "stone", price: 1, category: .decor, level: 1, stages: ["🪨"], days: [0]),
        GardenItem(id: "mailbox", price: 3, category: .decor, level: 2, stages: ["📫"], days: [0]),
        GardenItem(id: "fountain", price: 20, category: .decor, level: 4, stages: ["⛲"], days: [0]),
        GardenItem(id: "tractor", price: 30, category: .decor, level: 8, stages: ["🚜"], days: [0]),
    ]

    private static let byID = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) })

    static func item(_ id: String) -> GardenItem? { byID[id] }

    /// Which building an animal needs (for "first build a …").
    static func home(for group: HomeGroup) -> GardenItem {
        items.first { $0.houses == group && $0.id != "farmhouse" }!
    }

    /// Items a new level unlocks (for the celebration).
    static func unlocked(at level: Int) -> [GardenItem] {
        items.filter { $0.level == level }
    }
}

// MARK: - Farm levels

enum FarmLevels {
    /// XP needed for each level: level 2 at 10 XP, level 3 at 30, … then 100 more per level.
    static let levelXp = [0, 10, 30, 60, 100, 150, 210, 280, 360, 450]
    static let xpForCollecting = 3

    static func startXp(_ level: Int) -> Int {
        level <= levelXp.count ? levelXp[max(0, level - 1)] : levelXp[levelXp.count - 1] + 100 * (level - levelXp.count)
    }

    struct Level: Equatable {
        let level: Int
        let xpInLevel: Int
        let xpForNext: Int

        var progress: Double { xpForNext > 0 ? Double(xpInLevel) / Double(xpForNext) : 0 }
    }

    static func level(for xp: Int) -> Level {
        var level = 1
        while xp >= startXp(level + 1) { level += 1 }
        return Level(level: level, xpInLevel: xp - startXp(level), xpForNext: startXp(level + 1) - startXp(level))
    }
}
