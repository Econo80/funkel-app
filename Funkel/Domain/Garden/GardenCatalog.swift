import Foundation

// Everything that can go on Pip's farm (web/src/domain/garden.ts): plants grow
// and can be harvested, buildings take days to build, animals need a home, and
// everything does something: animals, trees and flowers give something once a
// day, little helpers (and the tractor) make a harvest bigger, the mill, barn
// and farmhouse turn goods into bread, cheese and pie, and the mailbox and
// horse make orders better.

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

/// Goods the farm makes. Stored under these names in `farmGoods`.
enum Produce: String, CaseIterable, Identifiable {
    case egg, milk, wheat, veg, apple, honey, wool, bacon, fish, wood, flowers, mushroom, bread, cheese, pie
    var id: String { rawValue }

    var emoji: String {
        switch self {
        case .egg: "🥚"
        case .milk: "🥛"
        case .wheat: "🌾"
        case .veg: "🥕"
        case .apple: "🍎"
        case .honey: "🍯"
        case .wool: "🧶"
        case .bacon: "🥓"
        case .fish: "🐟"
        case .wood: "🪵"
        case .flowers: "💐"
        case .mushroom: "🍄"
        case .bread: "🍞"
        case .cheese: "🧀"
        case .pie: "🥧"
        }
    }

    /// What it is worth in the farm shop and in orders: made goods are worth more than what went into them.
    var value: Int {
        switch self {
        case .bread, .cheese: 3
        case .pie: 5
        default: 1
        }
    }

    /// "2🌾 + 🥚": how many of each, in catalog order.
    static func text(_ goods: [Produce: Int]) -> String {
        allCases.compactMap { kind in
            guard let n = goods[kind], n > 0 else { return nil }
            return (n > 1 ? "\(n)" : "") + kind.emoji
        }.joined(separator: " + ")
    }

    static func value(_ goods: [Produce: Int]) -> Int {
        goods.reduce(0) { $0 + $1.key.value * $1.value }
    }
}

/// What a building makes, and from what.
struct Recipe: Equatable {
    let needs: [Produce: Int]
    let makes: Produce

    var text: String { "\(Produce.text(needs)) → \(makes.emoji)" }
}

/// Mailbox: one more order a day. Horse: every order pays one more star.
enum OrderBonus: String {
    case extraOrder, extraStar
}

/// Animals that need a home, by the kind of home.
enum HomeGroup: String {
    case dog, cat, chicken, farm, duck

    /// Who lives there, for "🐔 ×4" on the shop card.
    var resident: String {
        switch self {
        case .dog: "🐕"
        case .cat: "🐈"
        case .chicken: "🐔"
        case .farm: "🐄"
        case .duck: "🦆"
        }
    }
}

struct GardenItem: Identifiable, Equatable {
    struct Home: Equatable {
        let group: HomeGroup
        let capacity: Int
    }

    let id: String
    let price: Int
    /// Farm level that unlocks it.
    let level: Int
    let category: GardenCategory
    /// Picture per stage (emoji, or "art:<id>" for a drawn one); the last one may be a variant.
    let stages: [String]
    /// Days after placing when each stage starts (same length as stages).
    let days: [Int]
    var variants: [String]? = nil
    /// Columns × rows on the grid.
    var width = 1
    var height = 1
    /// A building: which animals live here, and how many.
    var houses: Home? = nil
    /// An animal that needs a finished home of this kind.
    var needs: HomeGroup? = nil
    /// Grown, it gives this once a day (hens, cows, bees, apple trees).
    var produce: Produce? = nil
    /// A crop: grown, it can be harvested, and then grows again.
    var harvest: Produce? = nil
    /// A helper: while it is on the farm, collecting these gives one more.
    var boosts: [Produce]? = nil
    var orders: OrderBonus? = nil
    /// A finished building that turns goods into something better (the mill bakes bread).
    var recipe: Recipe? = nil
    /// Roads, paths and fences join up with neighbours of the same kind.
    var connects = false

    /// What the shop shows: the finished look.
    var shopPicture: String { variants?.first ?? stages[stages.count - 1] }

    var nameKey: String { "garden.item." + id }
}

extension GardenItem {
    static let building = "🚧"

    static let all: [GardenItem] = [
        // Plants
        GardenItem(id: "flower", price: 3, level: 1, category: .plants, stages: ["🌱", "🌿", "🌷"], days: [0, 1, 3], variants: ["🌷", "🌻", "🌼", "🌸", "🌹", "🪻"], produce: .flowers),
        GardenItem(id: "wheat", price: 3, level: 1, category: .plants, stages: ["🌱", "🌾"], days: [0, 1], harvest: .wheat),
        GardenItem(id: "mushroom", price: 2, level: 1, category: .plants, stages: ["🍄"], days: [0], produce: .mushroom),
        GardenItem(id: "tree", price: 12, level: 1, category: .plants, stages: ["🌱", "🪴", "🌳"], days: [0, 3, 7], variants: ["🌳", "🌲"], produce: .wood),
        GardenItem(id: "vegetable", price: 4, level: 2, category: .plants, stages: ["🌱", "🌿", "🥕"], days: [0, 1, 2], variants: ["🥕", "🥬", "🎃", "🍅", "🥔"], harvest: .veg),
        GardenItem(id: "appletree", price: 20, level: 4, category: .plants, stages: ["🌱", "🪴", "🌳"], days: [0, 2, 4], produce: .apple),
        // Animals: small ones live anywhere and help; farm animals need their home first.
        GardenItem(id: "snail", price: 4, level: 1, category: .animals, stages: ["🐌"], days: [0], boosts: [.mushroom]),
        GardenItem(id: "ladybug", price: 5, level: 1, category: .animals, stages: ["🐞"], days: [0], boosts: [.veg]),
        GardenItem(id: "butterfly", price: 6, level: 1, category: .animals, stages: ["🦋"], days: [0], boosts: [.flowers]),
        GardenItem(id: "bee", price: 6, level: 1, category: .animals, stages: ["🐝"], days: [0], boosts: [.apple, .honey]),
        GardenItem(id: "rabbit", price: 8, level: 2, category: .animals, stages: ["🐇"], days: [0], produce: .wool),
        GardenItem(id: "dog", price: 15, level: 2, category: .animals, stages: ["🐕"], days: [0], needs: .dog, boosts: [.wool]),
        GardenItem(id: "chick", price: 6, level: 2, category: .animals, stages: ["🐣", "🐥", "🐔"], days: [0, 2, 4], needs: .chicken, produce: .egg),
        GardenItem(id: "duck", price: 8, level: 3, category: .animals, stages: ["🦆"], days: [0], needs: .duck, produce: .egg),
        GardenItem(id: "cat", price: 12, level: 3, category: .animals, stages: ["🐈"], days: [0], needs: .cat, boosts: [.wheat]),
        GardenItem(id: "sheep", price: 15, level: 4, category: .animals, stages: ["🐑"], days: [0], needs: .farm, produce: .wool),
        GardenItem(id: "goat", price: 15, level: 4, category: .animals, stages: ["🐐"], days: [0], needs: .farm, produce: .milk),
        GardenItem(id: "pig", price: 18, level: 5, category: .animals, stages: ["🐖"], days: [0], needs: .farm, produce: .bacon),
        GardenItem(id: "cow", price: 25, level: 5, category: .animals, stages: ["🐄"], days: [0], needs: .farm, produce: .milk),
        GardenItem(id: "horse", price: 30, level: 6, category: .animals, stages: ["🐴"], days: [0], needs: .farm, orders: .extraStar),
        // Buildings take a few days to build.
        GardenItem(id: "doghouse", price: 15, level: 2, category: .buildings, stages: [building, "art:doghouse"], days: [0, 1], houses: Home(group: .dog, capacity: 1)),
        GardenItem(id: "coop", price: 20, level: 2, category: .buildings, stages: [building, "art:coop"], days: [0, 1], houses: Home(group: .chicken, capacity: 4)),
        GardenItem(id: "house", price: 30, level: 3, category: .buildings, stages: ["🏡"], days: [0], houses: Home(group: .cat, capacity: 2)),
        GardenItem(id: "pond", price: 25, level: 3, category: .buildings, stages: [building, "art:pond"], days: [0, 1], width: 2, houses: Home(group: .duck, capacity: 3), produce: .fish),
        GardenItem(id: "barn", price: 40, level: 4, category: .buildings, stages: [building, "art:barn"], days: [0, 2], width: 2, height: 2, houses: Home(group: .farm, capacity: 4), recipe: Recipe(needs: [.milk: 2], makes: .cheese)),
        GardenItem(id: "beehive", price: 25, level: 5, category: .buildings, stages: [building, "art:beehive"], days: [0, 1], produce: .honey),
        GardenItem(id: "farmhouse", price: 60, level: 6, category: .buildings, stages: [building, "art:farmhouse"], days: [0, 3], width: 2, height: 2, houses: Home(group: .cat, capacity: 2), recipe: Recipe(needs: [.apple: 1, .egg: 1, .wheat: 1], makes: .pie)),
        GardenItem(id: "windmill", price: 50, level: 7, category: .buildings, stages: [building, "art:windmill"], days: [0, 2], height: 2, recipe: Recipe(needs: [.wheat: 2], makes: .bread)),
        // Roads, paths and fences are free, so children can lay out their farm.
        GardenItem(id: "road", price: 0, level: 1, category: .paths, stages: ["art:road"], days: [0], connects: true),
        GardenItem(id: "path", price: 0, level: 1, category: .paths, stages: ["art:path"], days: [0], connects: true),
        GardenItem(id: "fence", price: 0, level: 1, category: .paths, stages: ["art:fence"], days: [0], connects: true),
        // Decorations, and a few that help
        GardenItem(id: "stone", price: 1, level: 1, category: .decor, stages: ["🪨"], days: [0]),
        GardenItem(id: "mailbox", price: 3, level: 2, category: .decor, stages: ["📫"], days: [0], orders: .extraOrder),
        GardenItem(id: "fountain", price: 20, level: 4, category: .decor, stages: ["⛲"], days: [0], boosts: [.milk]),
        GardenItem(id: "tractor", price: 30, level: 8, category: .decor, stages: ["🚜"], days: [0], boosts: [.wheat, .veg]),
    ]

    private static let byID = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })

    static func with(id: String) -> GardenItem? { byID[id] }

    /// Items a new level unlocks (for the celebration).
    static func unlocked(at level: Int) -> [GardenItem] { all.filter { $0.level == level } }

    /// What it is good for, short, for the shop card: "🥚 jeden Tag", "🥕 +1", "2🌾 → 🍞".
    var uses: [String] {
        var uses: [String] = []
        if let houses { uses.append("\(houses.group.resident) ×\(houses.capacity)") }
        if let produce { uses.append("\(produce.emoji) " + String(localized: "garden.use.daily")) }
        if let harvest { uses.append("\(harvest.emoji) " + String(localized: "garden.use.harvest")) }
        if let boosts { uses.append(boosts.map(\.emoji).joined() + " +1") }
        if let recipe { uses.append(recipe.text) }
        if let orders { uses.append(String(localized: String.LocalizationValue("garden.use." + orders.rawValue))) }
        return uses
    }

    /// Which building an animal needs (for "first build a …").
    static func home(for group: HomeGroup) -> GardenItem {
        all.first { $0.houses?.group == group && $0.id != "farmhouse" }!
    }
}
