import Foundation

/// One square's item, stored like the web app: `{ itemId, plantedDay, variant?, collectedDay? }`.
struct GardenPlot: Codable, Equatable {
    var itemId: String
    var plantedDay: String
    var variant: String?
    /// Last day the daily gift (egg, milk, honey, apples) was collected.
    var collectedDay: String?

    init(itemId: String, plantedDay: String, variant: String? = nil, collectedDay: String? = nil) {
        self.itemId = itemId
        self.plantedDay = plantedDay
        self.variant = variant
        self.collectedDay = collectedDay
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
/// Spending comes from the wallet; lifetime stars never change here.
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

// MARK: Homes and placing

enum PlacementProblem: Equatable {
    case level, stars, space, home, full
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
    /// The farm shop buys goods in fives: 5 → 1 ⭐ (spendable only; lifetime stars stay learning stars).
    static let goodsPerStar = 5

    /// What a plot has ready: grown crops can be harvested (then they grow again);
    /// hens, cows, bees and apple trees give something once a day, from the day
    /// after they arrived.
    static func readyProduce(_ plot: GardenPlot, now: Date) -> Produce? {
        guard let item = plot.item, isGrown(plot, item: item, now: now) else { return nil }
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
        farm.goods[produce] = goods(produce) + 1
        return farm.withXp(Self.xpForCollecting)
    }

    /// Every cell with something ready, one per item.
    static func readyCells(_ garden: [GardenPlot?], now: Date) -> [Int] {
        garden.indices.filter { garden[$0].map { readyProduce($0, now: now) != nil } ?? false }
    }

    func selling() -> Farm {
        let stars = goodsCount / Self.goodsPerStar
        guard stars > 0 else { return self }
        var toSell = stars * Self.goodsPerStar
        var farm = self
        for kind in Produce.allCases {
            let sold = min(goods(kind), toSell)
            farm.goods[kind] = goods(kind) - sold
            toSell -= sold
        }
        farm.walletStars += stars
        return farm
    }
}

// MARK: Orders

extension Farm {
    /// Goods this farm can make: from what's on it, grown or not.
    static func producibleGoods(_ garden: [GardenPlot?]) -> [Produce] {
        var kinds = Set<Produce>()
        for plot in garden {
            if let item = plot?.item, let kind = item.produce ?? item.harvest { kinds.insert(kind) }
        }
        return Produce.allCases.filter(kinds.contains)
    }

    /// Three orders a day, for goods this farm can make. They pay better than the
    /// farm shop: about 1 ⭐ for every 3 goods, plus XP. Made once per day, the
    /// same ones the web app would make for this child.
    func withTodaysOrders(now: Date) -> Farm {
        let today = FarmDay.key(now)
        let kinds = Self.producibleGoods(garden)
        if let current = orders, current.day == today, !current.orders.isEmpty || kinds.isEmpty { return self }
        var rng = Mulberry32(seed: Mulberry32.hash("\(profileID):\(today)"))
        let big = level.level >= 5 ? 1 : 0
        let made: [FarmOrder] = kinds.isEmpty ? [] : (0..<3).map { i in
            let shuffled = rng.shuffled(kinds)
            var count = 1
            if kinds.count > 1, rng.next() < 0.5 { count = 2 }
            var wants: [String: Int] = [:]
            for kind in shuffled.prefix(count) { wants[kind.rawValue] = rng.int(2, 3 + big) }
            let total = wants.values.reduce(0, +)
            return FarmOrder(id: "\(today)-\(i)", wants: wants, stars: 1 + total / 3, xp: total * 3)
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
