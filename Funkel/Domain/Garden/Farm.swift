import Foundation

/// One square's item, stored like the web app: `{ itemId, plantedDay, variant?, collectedDay?, caredDay? }`.
struct GardenPlot: Codable, Equatable {
    var itemId: String
    var plantedDay: String
    var variant: String?
    /// Last day the daily gift (egg, milk, honey, apples) was collected.
    var collectedDay: String?
    /// Last fed, serviced or repaired (for things that need care).
    var caredDay: String?

    init(itemId: String, plantedDay: String, variant: String? = nil, collectedDay: String? = nil, caredDay: String? = nil) {
        self.itemId = itemId
        self.plantedDay = plantedDay
        self.variant = variant
        self.collectedDay = collectedDay
        self.caredDay = caredDay
    }

    var item: GardenItem? { GardenItem.with(id: itemId) }
}

/// Today's orders, stored as `farmOrders: { day, orders }`.
struct FarmOrders: Codable, Equatable {
    var day: String
    var orders: [FarmOrder]
}

struct FarmOrder: Codable, Equatable, Identifiable {
    var id: String
    /// Produce name → how many, e.g. `{ "egg": 3 }`.
    var wants: [String: Int]
    var stars: Int
    var xp: Int
    var done: Bool?

    func wants(_ kind: Produce) -> Int { wants[kind.rawValue] ?? 0 }
    var isDone: Bool { done == true }
}

/// Pip's farm as the rules see it (web/src/domain/garden.ts): every change
/// returns a new farm, and an impossible one returns the farm unchanged.
/// Spending comes from the wallet; lifetime stars never change here. A farm
/// year has four one-week seasons (fields wither in winter), and animals, the
/// tractor and buildings need looking after now and then or they stop working.
struct Farm: Equatable {
    /// The child's id, so each child gets their own daily orders.
    var profileID: String
    var walletStars: Int
    var garden: [GardenPlot?]
    var goods: [Produce: Int]
    var xp: Int
    var orders: FarmOrders?

    init(profileID: String = "", walletStars: Int = 0, garden: [GardenPlot?] = Farm.emptyGarden(), goods: [Produce: Int] = [:], xp: Int = 0, orders: FarmOrders? = nil) {
        self.profileID = profileID
        self.walletStars = walletStars
        self.garden = garden
        self.goods = Dictionary(uniqueKeysWithValues: Produce.allCases.map { ($0, goods[$0] ?? 0) })
        self.xp = xp
        self.orders = orders
    }

    func goods(_ kind: Produce) -> Int { goods[kind] ?? 0 }
    var goodsCount: Int { Produce.allCases.reduce(0) { $0 + goods($1) } }
    var level: FarmLevel { FarmLevel(xp: xp) }

    private func withXp(_ extra: Int) -> Farm {
        var farm = self
        farm.xp += extra
        return farm
    }
}

// MARK: Grid

extension Farm {
    /// Wider than a screen: the garden scrolls.
    static let columns = 16
    static let startRows = 8
    static let startSize = columns * startRows
    /// Each purchase adds four rows.
    static let landRowsPerPurchase = 4
    static let landPrices = [25, 40, 60]

    /// Gardens saved before the farm was widened were 6 columns wide, 4 rows plus 2 per land purchase.
    static let legacyColumns = 6
    private static let legacyStartRows = 4
    private static let legacyRowsPerPurchase = 2

    static func emptyGarden() -> [GardenPlot?] { Array(repeating: nil, count: startSize) }
    static func rows(_ garden: [GardenPlot?]) -> Int { (garden.count + columns - 1) / columns }
    var rows: Int { Self.rows(garden) }

    /// Moves an old 6-column garden into the wide one: everything keeps its row and
    /// column, and each piece of land bought earlier still counts as one purchase.
    static func widen(_ old: [GardenPlot?]) -> [GardenPlot?] {
        let oldRows = (old.count + legacyColumns - 1) / legacyColumns
        let purchases = max(0, Int((Double(oldRows - legacyStartRows) / Double(legacyRowsPerPurchase)).rounded(.up)))
        let rows = startRows + min(purchases, landPrices.count) * landRowsPerPurchase
        var garden = [GardenPlot?](repeating: nil, count: rows * columns)
        for (i, plot) in old.enumerated() {
            guard let plot else { continue }
            let target = (i / legacyColumns) * columns + i % legacyColumns
            if garden.indices.contains(target) { garden[target] = plot }
        }
        return garden
    }

    /// At least the starting size, in whole rows.
    static func normalized(_ garden: [GardenPlot?]) -> [GardenPlot?] {
        var g = garden
        let size = max(startSize, rows(g) * columns)
        while g.count < size { g.append(nil) }
        return g
    }

    /// XP for farms built before levels existed: what was spent on them.
    static func startingXp(_ garden: [GardenPlot?]) -> Int {
        let items = garden.reduce(0) { $0 + ($1?.item?.price ?? 0) }
        let bought = max(0, (rows(garden) - startRows) / landRowsPerPurchase)
        let land = landPrices.prefix(bought).reduce(0, +)
        return items + land
    }

    /// For each cell, the index of the item covering it (an item's top-left cell is its anchor).
    static func occupancy(_ garden: [GardenPlot?]) -> [Int?] {
        var covered = [Int?](repeating: nil, count: garden.count)
        for (anchor, plot) in garden.enumerated() {
            guard let item = plot?.item else { continue }
            let col = anchor % columns, row = anchor / columns
            for r in row..<(row + item.height) {
                for c in col..<(col + item.width) where c < columns {
                    let cell = r * columns + c
                    if covered.indices.contains(cell) { covered[cell] = anchor }
                }
            }
        }
        return covered
    }

    /// Where a big item goes when this cell is tapped: shifted left/up so it fits the grid.
    static func anchor(for cell: Int, of item: GardenItem, in garden: [GardenPlot?]) -> Int {
        let col = min(cell % columns, columns - item.width)
        let row = min(cell / columns, rows(garden) - item.height)
        return row * columns + col
    }

    static func fits(_ garden: [GardenPlot?], anchor: Int, item: GardenItem, ignoring ignore: Int? = nil) -> Bool {
        let col = anchor % columns, row = anchor / columns
        guard anchor >= 0, col + item.width <= columns, row + item.height <= rows(garden) else { return false }
        let covered = occupancy(garden)
        for r in row..<(row + item.height) {
            for c in col..<(col + item.width) {
                let cell = r * columns + c
                guard covered.indices.contains(cell) else { return false }
                if let owner = covered[cell], owner != ignore { return false }
            }
        }
        return true
    }

    struct Links: Equatable {
        var n = false, e = false, s = false, w = false
        var any: Bool { n || e || s || w }
    }

    /// Which neighbours (up, right, down, left) hold the same road, path or fence.
    static func connections(_ garden: [GardenPlot?], cell: Int) -> Links {
        let id = garden.indices.contains(cell) ? garden[cell]?.itemId : nil
        func same(_ i: Int) -> Bool { garden.indices.contains(i) && id != nil && garden[i]?.itemId == id }
        let col = cell % columns
        return Links(
            n: same(cell - columns),
            e: col < columns - 1 && same(cell + 1),
            s: same(cell + columns),
            w: col > 0 && same(cell - 1)
        )
    }

    // MARK: Land

    /// Price of the next piece of land, or nil when the garden is as big as it gets.
    static func nextLandPrice(_ garden: [GardenPlot?]) -> Int? {
        let bought = (rows(garden) - startRows) / landRowsPerPurchase
        return landPrices.indices.contains(bought) ? landPrices[bought] : nil
    }

    var nextLandPrice: Int? { Self.nextLandPrice(garden) }

    func buyingLand() -> Farm {
        guard let price = nextLandPrice, walletStars >= price else { return self }
        var farm = self
        farm.walletStars -= price
        farm.garden += [GardenPlot?](repeating: nil, count: Self.columns * Self.landRowsPerPurchase)
        return farm.withXp(price)
    }
}

// MARK: Growing

extension Farm {
    static func stageIndex(_ plot: GardenPlot, item: GardenItem, now: Date) -> Int {
        let age = FarmDay.daysSince(plot.plantedDay, now: now)
        var stage = 0
        for (i, d) in item.days.enumerated() where age >= d { stage = i }
        return stage
    }

    static func isGrown(_ plot: GardenPlot, item: GardenItem, now: Date) -> Bool {
        stageIndex(plot, item: item, now: now) == item.stages.count - 1
    }

    /// The picture a plot shows today: an emoji, or "art:<id>" for a drawn one.
    static func picture(of plot: GardenPlot, now: Date) -> String {
        guard let item = plot.item else { return "" }
        if isWithered(plot, now: now) { return item.id == "flower" ? "🥀" : "🍂" }
        let stage = stageIndex(plot, item: item, now: now)
        if stage == item.stages.count - 1, let variant = plot.variant { return variant }
        return item.stages[stage]
    }

    /// Days until the next stage (growing, or a building being finished), or nil when done.
    static func daysUntilNextStage(_ plot: GardenPlot, now: Date) -> Int? {
        guard let item = plot.item else { return nil }
        let age = FarmDay.daysSince(plot.plantedDay, now: now)
        return item.days.first { $0 > age }.map { $0 - age }
    }

    static func isUnderConstruction(_ plot: GardenPlot, now: Date) -> Bool {
        picture(of: plot, now: now) == GardenItem.building
    }
}

// MARK: Seasons

/// A farm year has four seasons of a week each, the same for every child.
enum Season: String, CaseIterable {
    case spring, summer, autumn, winter

    var emoji: String {
        switch self {
        case .spring: "🌸"
        case .summer: "☀️"
        case .autumn: "🍂"
        case .winter: "❄️"
        }
    }
}

/// Today's season, which day of it (0–6), the days left, and the day it began.
struct SeasonDay: Equatable {
    let season: Season
    let day: Int
    let daysLeft: Int
    let startDay: String
}

extension Farm {
    static let seasonDays = 7
    /// The first farm spring began on this Monday; every season is a week, the same for every child.
    static let seasonsStart = "2026-11-02"

    static func season(on now: Date) -> SeasonDay {
        let year = Season.allCases.count * seasonDays
        // Before the first farm year it is always early spring.
        let index = max(0, FarmDay.daysSince(seasonsStart, now: now)) % year
        let day = index % seasonDays
        return SeasonDay(
            season: Season.allCases[index / seasonDays],
            day: day,
            daysLeft: seasonDays - day,
            startDay: FarmDay.key(FarmDay.adding(-day, to: now))
        )
    }

    /// The day the latest winter began (none before the first farm year).
    static func lastWinterStart(_ now: Date) -> String? {
        let year = Season.allCases.count * seasonDays, winter = 3 * seasonDays
        let index = ((FarmDay.daysSince(seasonsStart, now: now) % year) + year) % year
        let start = FarmDay.key(FarmDay.adding(-((index - winter + year) % year), to: now))
        return start < seasonsStart ? nil : start
    }

    /// A field or flower from before the last winter: withered, to be cleared and planted again.
    static func isWithered(_ plot: GardenPlot, now: Date) -> Bool {
        guard plot.item?.annual == true, let winter = lastWinterStart(now) else { return false }
        return plot.plantedDay < winter
    }

    /// Trees and bees rest in winter.
    static func restsInWinter(_ item: GardenItem) -> Bool {
        item.category == .plants || item.id == "beehive"
    }
}

// MARK: Care

extension Farm {
    /// Care is counted from here for farms built before it existed, so nobody starts with a big bill.
    static let careStart = "2026-11-05"

    /// Days until this needs care again (0 = now); nil if it never does.
    static func daysUntilCare(_ plot: GardenPlot, now: Date) -> Int? {
        guard let care = plot.item?.care else { return nil }
        let last = max(plot.caredDay ?? plot.plantedDay, careStart)
        return max(0, care.every - FarmDay.daysSince(last, now: now))
    }

    /// It's hungry, due a service or a repair: until then it stops working (it stays on the farm).
    static func needsCare(_ plot: GardenPlot, now: Date) -> Bool {
        daysUntilCare(plot, now: now) == 0
    }

    /// Finished, looked after and not resting for the winter: it does what it does.
    static func isWorking(_ plot: GardenPlot, item: GardenItem, now: Date) -> Bool {
        isGrown(plot, item: item, now: now)
            && !needsCare(plot, now: now)
            && !isWithered(plot, now: now)
            && !(restsInWinter(item) && season(on: now).season == .winter)
    }

    /// Every item that needs care now (by its top-left cell).
    static func careCells(_ garden: [GardenPlot?], now: Date) -> [Int] {
        garden.indices.filter { garden[$0].map { needsCare($0, now: now) } ?? false }
    }

    /// What it costs to look after this cell now, or nil if it doesn't need it.
    static func careCost(_ garden: [GardenPlot?], cell: Int, now: Date) -> Int? {
        let covered = occupancy(garden)
        guard covered.indices.contains(cell), let anchor = covered[cell], let plot = garden[anchor],
              needsCare(plot, now: now)
        else { return nil }
        return plot.item?.care?.cost
    }

    /// Feeds, services or repairs it (paid from the wallet; every star spent is one XP).
    func caring(for cell: Int, now: Date) -> Farm {
        let covered = Self.occupancy(garden)
        guard covered.indices.contains(cell), let anchor = covered[cell],
              let cost = Self.careCost(garden, cell: cell, now: now), walletStars >= cost
        else { return self }
        var farm = self
        farm.garden[anchor]?.caredDay = FarmDay.key(now)
        farm.walletStars -= cost
        return farm.withXp(cost)
    }

    /// Looks after everything that needs it, as far as the stars go.
    func caringForAll(now: Date) -> Farm {
        Self.careCells(garden, now: now).reduce(self) { next, cell in next.caring(for: cell, now: now) }
    }
}

// MARK: Homes and placing

enum PlacementProblem: Equatable {
    case level, stars, space, home, full, winter
}

extension Farm {
    /// Places for this kind of animal in finished homes, and how many are taken.
    static func homeSpace(_ garden: [GardenPlot?], group: HomeGroup, now: Date) -> (capacity: Int, used: Int) {
        var capacity = 0, used = 0
        for plot in garden {
            guard let plot, let item = plot.item else { continue }
            if let houses = item.houses, houses.group == group, isGrown(plot, item: item, now: now) { capacity += houses.capacity }
            if item.needs == group { used += 1 }
        }
        return (capacity, used)
    }

    func homeSpace(_ group: HomeGroup, now: Date) -> (capacity: Int, used: Int) {
        Self.homeSpace(garden, group: group, now: now)
    }

    func placementProblem(at cell: Int, itemID: String, now: Date) -> PlacementProblem? {
        guard let item = GardenItem.with(id: itemID) else { return .stars }
        if level.level < item.level { return .level }
        if walletStars < item.price { return .stars }
        if item.annual && Self.season(on: now).season == .winter { return .winter }
        if let needs = item.needs {
            let space = homeSpace(needs, now: now)
            if space.capacity == 0 { return .home }
            if space.used >= space.capacity { return .full }
        }
        if !Self.fits(garden, anchor: Self.anchor(for: cell, of: item, in: garden), item: item) { return .space }
        return nil
    }

    /// Places an item (paid from the wallet); every star spent on the farm is one XP.
    func placing<R: RandomNumberGenerator>(_ itemID: String, at cell: Int, now: Date, using rng: inout R) -> Farm {
        guard let item = GardenItem.with(id: itemID), garden.indices.contains(cell),
              placementProblem(at: cell, itemID: itemID, now: now) == nil
        else { return self }
        var farm = self
        farm.garden[Self.anchor(for: cell, of: item, in: garden)] = GardenPlot(
            itemId: itemID, plantedDay: FarmDay.key(now), variant: item.variants?.randomElement(using: &rng)
        )
        farm.walletStars -= item.price
        return farm.withXp(item.price)
    }

    func placing(_ itemID: String, at cell: Int, now: Date) -> Farm {
        var rng = SystemRandomNumberGenerator()
        return placing(itemID, at: cell, now: now, using: &rng)
    }

    /// Moves whatever covers `from` so that `to` is its new top-left corner (shifted to fit). Keeps its age.
    func moving(from: Int, to: Int) -> Farm {
        let covered = Self.occupancy(garden)
        guard covered.indices.contains(from), let anchor = covered[from], let plot = garden[anchor], let item = plot.item else { return self }
        let target = Self.anchor(for: to, of: item, in: garden)
        guard target != anchor, Self.fits(garden, anchor: target, item: item, ignoring: anchor) else { return self }
        var farm = self
        farm.garden[anchor] = nil
        farm.garden[target] = plot
        return farm
    }

    /// A home can only be cleared if its animals still have room elsewhere.
    func canClear(_ cell: Int, now: Date) -> Bool {
        let covered = Self.occupancy(garden)
        guard covered.indices.contains(cell), let anchor = covered[cell], let plot = garden[anchor] else { return false }
        guard let item = plot.item, let houses = item.houses, Self.isGrown(plot, item: item, now: now) else { return true }
        let space = homeSpace(houses.group, now: now)
        return space.used <= space.capacity - houses.capacity
    }

    /// Clears whatever covers this cell (no refund, like real gardening).
    func clearing(_ cell: Int, now: Date) -> Farm {
        let covered = Self.occupancy(garden)
        guard covered.indices.contains(cell), let anchor = covered[cell], canClear(cell, now: now) else { return self }
        var farm = self
        farm.garden[anchor] = nil
        return farm
    }
}

// MARK: Harvest and daily gifts

extension Farm {
    static let xpForCollecting = 3
    /// The farm shop pays 1 ⭐ for every 5 goods; bread and cheese count as 3, a pie
    /// as 5 (spendable only; lifetime stars stay learning stars).
    static let goodsPerStar = 5

    /// What a plot has ready: grown crops can be harvested (then they grow again);
    /// hens, cows, bees and apple trees give something once a day, from the day
    /// after they arrived.
    static func readyProduce(_ plot: GardenPlot, now: Date) -> Produce? {
        guard let item = plot.item, isWorking(plot, item: item, now: now) else { return nil }
        if let harvest = item.harvest { return harvest }
        guard let produce = item.produce, FarmDay.daysSince(plot.plantedDay, now: now) >= 1 else { return nil }
        return plot.collectedDay == FarmDay.key(now) ? nil : produce
    }

    func collecting(_ cell: Int, now: Date) -> Farm {
        let covered = Self.occupancy(garden)
        guard covered.indices.contains(cell), let anchor = covered[cell], var plot = garden[anchor],
              let produce = Self.readyProduce(plot, now: now)
        else { return self }
        // A harvested crop starts growing again; other gifts wait for tomorrow.
        if plot.item?.harvest != nil {
            plot.plantedDay = FarmDay.key(now)
        } else {
            plot.collectedDay = FarmDay.key(now)
        }
        var farm = self
        farm.garden[anchor] = plot
        farm.goods[produce] = goods(produce) + collectAmount(produce, now: now)
        return farm.withXp(Self.xpForCollecting)
    }

    /// Working items on the farm, one per kind (one of a kind is enough for its effect).
    private static func finishedKinds(_ garden: [GardenPlot?], now: Date) -> [GardenItem] {
        var seen = Set<String>()
        var kinds: [GardenItem] = []
        for plot in garden {
            guard let plot, let item = plot.item, !seen.contains(item.id), isWorking(plot, item: item, now: now) else { continue }
            seen.insert(item.id)
            kinds.append(item)
        }
        return kinds
    }

    /// Helpers on the farm that make collecting this good give more.
    func helpers(for produce: Produce, now: Date) -> [GardenItem] {
        Self.finishedKinds(garden, now: now).filter { $0.boosts?.contains(produce) == true }
    }

    /// How many of a good one collection gives: one, plus one for each kind of helper.
    func collectAmount(_ produce: Produce, now: Date) -> Int { 1 + helpers(for: produce, now: now).count }

    /// Every cell with something ready, one per item.
    static func readyCells(_ garden: [GardenPlot?], now: Date) -> [Int] {
        garden.indices.filter { garden[$0].map { readyProduce($0, now: now) != nil } ?? false }
    }

    /// What the farm shop takes: the most whole stars' worth that the goods add up to
    /// exactly, using plain goods first so bread, cheese and pies stay for orders.
    private var shopSale: (stars: Int, sold: [Produce: Int]) {
        let kinds = Produce.allCases.enumerated().sorted { ($0.element.value, $0.offset) < ($1.element.value, $1.offset) }.map(\.element)
        let total = Produce.value(goods)
        // reachable[i][v]: some choice from the first i kinds is worth exactly v.
        var reachable: [[Bool]] = [[true] + Array(repeating: false, count: total)]
        for kind in kinds {
            let before = reachable[reachable.count - 1]
            let have = goods(kind)
            reachable.append(before.indices.map { v in
                var n = 0
                while n <= have && n * kind.value <= v {
                    if before[v - n * kind.value] { return true }
                    n += 1
                }
                return false
            })
        }
        var target = total - total % Self.goodsPerStar
        while target > 0 && !reachable[kinds.count][target] { target -= Self.goodsPerStar }
        // Walk back from the most valuable kind, taking as few of each as still works.
        var sold: [Produce: Int] = [:]
        var rest = target
        for i in stride(from: kinds.count - 1, through: 0, by: -1) {
            let kind = kinds[i]
            var n = 0
            while !reachable[i][rest - n * kind.value] { n += 1 }
            sold[kind] = n
            rest -= n * kind.value
        }
        return (target / Self.goodsPerStar, sold)
    }

    /// Stars the farm shop pays for what is in the storage.
    var sellableStars: Int { shopSale.stars }

    /// Sells to the farm shop; what doesn't add up to a whole star stays in the storage.
    func selling() -> Farm {
        let sale = shopSale
        guard sale.stars > 0 else { return self }
        var farm = self
        for kind in Produce.allCases { farm.goods[kind] = goods(kind) - (sale.sold[kind] ?? 0) }
        farm.walletStars += sale.stars
        return farm
    }
}

// MARK: Making things

extension Farm {
    /// The recipe of the finished building covering this cell, if it has one.
    func recipe(at cell: Int, now: Date) -> Recipe? {
        let covered = Self.occupancy(garden)
        guard covered.indices.contains(cell), let anchor = covered[cell], let plot = garden[anchor],
              let item = plot.item, let recipe = item.recipe, Self.isWorking(plot, item: item, now: now)
        else { return nil }
        return recipe
    }

    private func has(_ wants: [Produce: Int]) -> Bool {
        wants.allSatisfy { goods($0.key) >= $0.value }
    }

    func canMake(at cell: Int, now: Date) -> Bool {
        recipe(at: cell, now: now).map { has($0.needs) } ?? false
    }

    /// The mill, barn or farmhouse makes one batch from goods in the storage.
    func making(at cell: Int, now: Date) -> Farm {
        guard let recipe = recipe(at: cell, now: now), has(recipe.needs) else { return self }
        var farm = self
        for (kind, n) in recipe.needs { farm.goods[kind] = goods(kind) - n }
        farm.goods[recipe.makes] = goods(recipe.makes) + 1
        return farm.withXp(Self.xpForCollecting)
    }
}

// MARK: Orders

extension Farm {
    /// Goods this farm can make: from what's on it, grown or not, and what its buildings make from those.
    static func producibleGoods(_ garden: [GardenPlot?]) -> [Produce] {
        var kinds = Set<Produce>()
        var recipes: [Recipe] = []
        for plot in garden {
            guard let item = plot?.item else { continue }
            if let kind = item.produce ?? item.harvest { kinds.insert(kind) }
            if let recipe = item.recipe { recipes.append(recipe) }
        }
        for recipe in recipes where recipe.needs.keys.allSatisfy(kinds.contains) { kinds.insert(recipe.makes) }
        return Produce.allCases.filter(kinds.contains)
    }

    /// A working mailbox or horse on the farm.
    private static func has(_ bonus: OrderBonus, in garden: [GardenPlot?], now: Date) -> Bool {
        finishedKinds(garden, now: now).contains { $0.orders == bonus }
    }

    /// Three orders a day (four with a mailbox), for goods this farm can make. They
    /// pay better than the farm shop: about 1 ⭐ for every 3 goods (bread and cheese
    /// count 3, a pie 5), one more with a horse, plus XP. Made once per day, the
    /// same ones the web app would make for this child.
    func withTodaysOrders(now: Date) -> Farm {
        let today = FarmDay.key(now)
        let kinds = Self.producibleGoods(garden)
        if let current = orders, current.day == today, !current.orders.isEmpty || kinds.isEmpty { return self }
        var rng = Mulberry32(seed: Mulberry32.hash("\(profileID):\(today)"))
        let big = level.level >= 5 ? 1 : 0
        let count = Self.has(.extraOrder, in: garden, now: now) ? 4 : 3
        let extraStar = Self.has(.extraStar, in: garden, now: now) ? 1 : 0
        let made: [FarmOrder] = kinds.isEmpty ? [] : (0..<count).map { i in
            let shuffled = rng.shuffled(kinds)
            var picks = 1
            if kinds.count > 1, rng.next() < 0.5 { picks = 2 }
            var wants: [String: Int] = [:]
            for kind in shuffled.prefix(picks) { wants[kind.rawValue] = kind.value > 1 ? rng.int(1, 2) : rng.int(2, 3 + big) }
            let value = wants.reduce(0) { $0 + (Produce(rawValue: $1.key)?.value ?? 1) * $1.value }
            return FarmOrder(id: "\(today)-\(i)", wants: wants, stars: 1 + value / 3 + extraStar, xp: value * 3)
        }
        var farm = self
        farm.orders = FarmOrders(day: today, orders: made)
        return farm
    }

    func canFulfil(_ order: FarmOrder) -> Bool {
        !order.isDone && Produce.allCases.allSatisfy { goods($0) >= order.wants($0) }
    }

    func fulfilling(_ orderID: String) -> Farm {
        guard let current = orders, let order = current.orders.first(where: { $0.id == orderID }), canFulfil(order) else { return self }
        var farm = self
        for kind in Produce.allCases { farm.goods[kind] = goods(kind) - order.wants(kind) }
        farm.walletStars += order.stars
        farm.orders?.orders = current.orders.map { o in
            var o = o
            if o.id == orderID { o.done = true }
            return o
        }
        return farm.withXp(order.xp)
    }
}

// MARK: Levels

/// Farm level from XP: level 2 at 10 XP, level 3 at 30, … then 100 more per level.
struct FarmLevel: Equatable {
    let level: Int
    let xpInLevel: Int
    let xpForNext: Int

    private static let levelXp = [0, 10, 30, 60, 100, 150, 210, 280, 360, 450]

    static func startXp(_ level: Int) -> Int {
        level <= levelXp.count ? levelXp[max(0, level - 1)] : levelXp[levelXp.count - 1] + 100 * (level - levelXp.count)
    }

    init(level: Int, xpInLevel: Int, xpForNext: Int) {
        self.level = level
        self.xpInLevel = xpInLevel
        self.xpForNext = xpForNext
    }

    init(xp: Int) {
        var level = 1
        while xp >= Self.startXp(level + 1) { level += 1 }
        self.init(level: level, xpInLevel: xp - Self.startXp(level), xpForNext: Self.startXp(level + 1) - Self.startXp(level))
    }

    var progress: Double { xpForNext > 0 ? Double(xpInLevel) / Double(xpForNext) : 0 }
}

// MARK: Days

/// Farm days are local calendar days, "YYYY-MM-DD", like the web app's `dayKey`.
enum FarmDay {
    static func key(_ date: Date, calendar: Calendar = .current) -> String {
        Backup.dayKey(date, calendar: calendar)
    }

    /// The same time of day, some days later (or earlier, for negative days).
    static func adding(_ days: Int, to date: Date, calendar: Calendar = .current) -> Date {
        calendar.date(byAdding: .day, value: days, to: date) ?? date
    }

    /// Whole days from `from` (a day key) to the day of `now`.
    static func daysSince(_ from: String, now: Date) -> Int {
        guard let start = dayNumber(from), let end = dayNumber(key(now)) else { return 0 }
        return end - start
    }

    /// Days since 1970-01-01 for "YYYY-MM-DD" (proleptic Gregorian, no time zones involved).
    static func dayNumber(_ key: String) -> Int? {
        let parts = key.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        let (y0, m, d) = (parts[0], parts[1], parts[2])
        let y = m <= 2 ? y0 - 1 : y0
        let era = (y >= 0 ? y : y - 399) / 400
        let yoe = y - era * 400
        let doy = (153 * (m + (m > 2 ? -3 : 9)) + 2) / 5 + d - 1
        let doe = yoe * 365 + yoe / 4 - yoe / 100 + doy
        return era * 146_097 + doe - 719_468
    }
}

// MARK: Seeded orders

/// The web app's seeded generator (mulberry32) and string hash, so a child's
/// daily orders are the same in both apps.
struct Mulberry32 {
    private var state: UInt32

    init(seed: Int32) {
        state = UInt32(bitPattern: seed)
    }

    /// A number in [0, 1).
    mutating func next() -> Double {
        state &+= 0x6D2B_79F5
        var t = state
        t = (t ^ (t >> 15)) &* (t | 1)
        t ^= t &+ ((t ^ (t >> 7)) &* (t | 61))
        return Double(t ^ (t >> 14)) / 4_294_967_296
    }

    /// Integer in [min, max], inclusive.
    mutating func int(_ min: Int, _ max: Int) -> Int {
        max <= min ? min : min + Int(next() * Double(max - min + 1))
    }

    mutating func shuffled<T>(_ items: [T]) -> [T] {
        var result = items
        var i = result.count - 1
        while i > 0 {
            let j = Int(next() * Double(i + 1))
            result.swapAt(i, j)
            i -= 1
        }
        return result
    }

    /// `[...s].reduce((h, ch) => (Math.imul(h, 31) + ch.charCodeAt(0)) | 0, 7)`
    static func hash(_ text: String) -> Int32 {
        text.unicodeScalars.reduce(Int32(7)) { h, scalar in
            h &* 31 &+ Int32(String(scalar).utf16.first ?? 0)
        }
    }
}
