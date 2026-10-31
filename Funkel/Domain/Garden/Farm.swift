import Foundation

/// A daily order: goods wanted, and what it pays. Stored like the web app's
/// `{ id, wants: { egg: 2 }, stars, xp, done? }`.
struct FarmOrder: Codable, Equatable, Identifiable {
    var id: String
    var wants: [Produce: Int]
    var stars: Int
    var xp: Int
    var done: Bool? = nil

    var isDone: Bool { done == true }
    var total: Int { wants.values.reduce(0, +) }

    enum CodingKeys: String, CodingKey { case id, wants, stars, xp, done }

    init(id: String, wants: [Produce: Int], stars: Int, xp: Int, done: Bool? = nil) {
        self.id = id
        self.wants = wants
        self.stars = stars
        self.xp = xp
        self.done = done
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        let raw = try c.decodeIfPresent([String: Int].self, forKey: .wants) ?? [:]
        wants = Dictionary(uniqueKeysWithValues: raw.compactMap { key, value in Produce(rawValue: key).map { ($0, value) } })
        stars = try c.decodeIfPresent(Int.self, forKey: .stars) ?? 0
        xp = try c.decodeIfPresent(Int.self, forKey: .xp) ?? 0
        done = try c.decodeIfPresent(Bool.self, forKey: .done)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(Dictionary(uniqueKeysWithValues: wants.map { ($0.key.rawValue, $0.value) }), forKey: .wants)
        try c.encode(stars, forKey: .stars)
        try c.encode(xp, forKey: .xp)
        try c.encodeIfPresent(done, forKey: .done)
    }
}

struct FarmOrders: Codable, Equatable {
    var day: String
    var orders: [FarmOrder]
}

/// Everything about one child's farm: the meadow, the store, XP, today's
/// orders, the wallet it spends from and today's garden time. A value: every
/// rule returns a new farm (the same one when nothing happens), like the web
/// app's pure functions in web/src/domain/garden.ts. Everything is paid from
/// the wallet; lifetime stars never change here.
struct Farm: Equatable {
    /// The child's id as the web app knows it (seeds the daily orders).
    var profileID: String
    var walletStars: Int
    var garden = Garden.empty()
    var goods = Farm.emptyGoods
    /// Farm XP: stars spent on the farm, collecting and orders.
    var xp = 0
    var orders: FarmOrders? = nil
    /// Minutes a day in Pips Garten (0 = no limit).
    var minutesPerDay = Farm.defaultMinutesPerDay
    /// Time spent in the garden on `gardenDay`, and extra minutes a grown-up gave for that day.
    var gardenDay: String? = nil
    var gardenSeconds: Int? = nil
    var gardenBonusMinutes: Int? = nil

    static let emptyGoods = Dictionary(uniqueKeysWithValues: Produce.allCases.map { ($0, 0) })
    static let goodsPerStar = 5
    static let minutesChoices = [10, 15, 20, 30, 45, 0]
    static let defaultMinutesPerDay = 20
    static let bonusChoices = [5, 10, 15]

    var level: FarmLevels.Level { FarmLevels.level(for: xp) }
    var goodsCount: Int { goods.values.reduce(0, +) }
    func goods(_ kind: Produce) -> Int { goods[kind] ?? 0 }

    private func addingXp(_ amount: Int) -> Farm {
        var next = self
        next.xp += amount
        return next
    }

    // MARK: Land

    func buyingLand() -> Farm {
        guard let price = garden.nextLandPrice, walletStars >= price else { return self }
        var next = self
        next.walletStars -= price
        next.garden.plots += Array(repeating: nil, count: Garden.columns * Garden.rowsPerPurchase)
        return next.addingXp(price)
    }

    // MARK: Placing

    enum PlacementProblem: String {
        case level, stars, space, home, full
    }

    func placementProblem(at cell: Int, itemID: String, now: Date, calendar: Calendar = .current) -> PlacementProblem? {
        guard let item = GardenCatalog.item(itemID) else { return .stars }
        if level.level < item.level { return .level }
        if walletStars < item.price { return .stars }
        if let needs = item.needs {
            let space = garden.homeSpace(needs, now: now, calendar: calendar)
            if space.capacity == 0 { return .home }
            if space.used >= space.capacity { return .full }
        }
        if !garden.fits(item, at: garden.anchor(for: cell, item: item)) { return .space }
        return nil
    }

    /// Places an item (paid from the wallet); every star spent on the farm is one XP.
    func placing(_ itemID: String, at cell: Int, now: Date, rng: GardenRandom, calendar: Calendar = .current) -> Farm {
        guard let item = GardenCatalog.item(itemID), cell >= 0, cell < garden.count,
              placementProblem(at: cell, itemID: itemID, now: now, calendar: calendar) == nil else { return self }
        var next = self
        let variant = item.variants.flatMap { rng.element($0) }
        next.garden[garden.anchor(for: cell, item: item)] = GardenPlot(itemID: itemID, plantedDay: GardenDays.key(now, calendar: calendar), variant: variant)
        next.walletStars -= item.price
        return next.addingXp(item.price)
    }

    /// Moves whatever covers `from` so that `to` is its new top-left corner (shifted to fit). Keeps its age.
    func moving(from: Int, to: Int) -> Farm {
        guard let anchor = self.anchor(at: from), let plot = garden[anchor], let item = plot.item else { return self }
        let target = garden.anchor(for: to, item: item)
        guard target != anchor, garden.fits(item, at: target, ignoring: anchor) else { return self }
        var next = self
        next.garden[anchor] = nil
        next.garden[target] = plot
        return next
    }

    /// A home can only be cleared if its animals still have room elsewhere.
    func canClear(_ cell: Int, now: Date, calendar: Calendar = .current) -> Bool {
        guard let anchor = self.anchor(at: cell), let plot = garden[anchor] else { return false }
        guard let item = plot.item, let group = item.houses, plot.isGrown(now: now, calendar: calendar) else { return true }
        let space = garden.homeSpace(group, now: now, calendar: calendar)
        return space.used <= space.capacity - item.capacity
    }

    /// Clears whatever covers this square (no refund, like real gardening).
    func clearing(_ cell: Int, now: Date, calendar: Calendar = .current) -> Farm {
        guard let anchor = self.anchor(at: cell), canClear(cell, now: now, calendar: calendar) else { return self }
        var next = self
        next.garden[anchor] = nil
        return next
    }

    /// The anchor of the item covering a square, if any.
    func anchor(at cell: Int) -> Int? {
        let covered = garden.occupancy()
        return covered.indices.contains(cell) ? covered[cell] : nil
    }

    // MARK: Harvest and daily gifts

    func collecting(_ cell: Int, now: Date, calendar: Calendar = .current) -> Farm {
        guard let anchor = self.anchor(at: cell), let plot = garden[anchor],
              let produce = plot.readyProduce(now: now, calendar: calendar) else { return self }
        var next = self
        var collected = plot
        // A harvested crop starts growing again; other gifts wait for tomorrow.
        if plot.item?.harvest != nil {
            collected.plantedDay = GardenDays.key(now, calendar: calendar)
        } else {
            collected.collectedDay = GardenDays.key(now, calendar: calendar)
        }
        next.garden[anchor] = collected
        next.goods[produce, default: 0] += 1
        return next.addingXp(FarmLevels.xpForCollecting)
    }

    /// The farm shop buys goods in fives: 5 → 1 ⭐ (spendable only; lifetime stars stay learning stars).
    func sellingGoods() -> Farm {
        let stars = goodsCount / Self.goodsPerStar
        guard stars > 0 else { return self }
        var toSell = stars * Self.goodsPerStar
        var next = self
        for kind in Produce.allCases {
            let sold = min(goods(kind), toSell)
            next.goods[kind] = goods(kind) - sold
            toSell -= sold
        }
        next.walletStars += stars
        return next
    }

    // MARK: Orders

    /// Three orders a day, for goods this farm can make. They pay better than the
    /// farm shop: about 1 ⭐ for every 3 goods, plus XP. Made once per day.
    func withTodaysOrders(now: Date, calendar: Calendar = .current) -> Farm {
        let today = GardenDays.key(now, calendar: calendar)
        let kinds = garden.producibleGoods
        if let current = orders, current.day == today, !current.orders.isEmpty || kinds.isEmpty { return self }
        let rng = GardenRandom(seed: GardenRandom.hash("\(profileID):\(today)"))
        let big = level.level >= 5 ? 1 : 0
        let list: [FarmOrder] = kinds.isEmpty ? [] : (0..<3).map { i in
            let shuffled = rng.shuffled(kinds)
            let picked = shuffled.prefix(kinds.count > 1 && rng.next() < 0.5 ? 2 : 1)
            var wants: [Produce: Int] = [:]
            for kind in picked { wants[kind] = rng.int(2, 3 + big) }
            let total = wants.values.reduce(0, +)
            return FarmOrder(id: "\(today)-\(i)", wants: wants, stars: 1 + total / 3, xp: total * 3)
        }
        var next = self
        next.orders = FarmOrders(day: today, orders: list)
        return next
    }

    func canFulfil(_ order: FarmOrder) -> Bool {
        !order.isDone && Produce.allCases.allSatisfy { goods($0) >= (order.wants[$0] ?? 0) }
    }

    func fulfilling(_ orderID: String) -> Farm {
        guard let current = orders, let order = current.orders.first(where: { $0.id == orderID }), canFulfil(order) else { return self }
        var next = self
        for kind in Produce.allCases { next.goods[kind] = goods(kind) - (order.wants[kind] ?? 0) }
        next.walletStars += order.stars
        next.orders?.orders = current.orders.map { $0.id == orderID ? FarmOrder(id: $0.id, wants: $0.wants, stars: $0.stars, xp: $0.xp, done: true) : $0 }
        return next.addingXp(order.xp)
    }

    // MARK: Garden time

    /// Seconds of garden time left today, or nil when there's no limit.
    func gardenSecondsLeft(now: Date, calendar: Calendar = .current) -> Int? {
        guard minutesPerDay > 0 else { return nil }
        let today = gardenDay == GardenDays.key(now, calendar: calendar)
        let allowed = (minutesPerDay + (today ? gardenBonusMinutes ?? 0 : 0)) * 60
        return max(0, allowed - (today ? gardenSeconds ?? 0 : 0))
    }

    /// Counts time spent in the garden (a new day starts from zero).
    func addingGardenTime(_ seconds: Int, now: Date, calendar: Calendar = .current) -> Farm {
        guard seconds > 0 else { return self }
        let today = GardenDays.key(now, calendar: calendar)
        let same = gardenDay == today
        var next = self
        next.gardenDay = today
        next.gardenSeconds = (same ? gardenSeconds ?? 0 : 0) + seconds
        next.gardenBonusMinutes = same ? gardenBonusMinutes ?? 0 : 0
        return next
    }

    /// A grown-up gives extra garden minutes, for today only.
    func grantingGardenMinutes(_ minutes: Int, now: Date, calendar: Calendar = .current) -> Farm {
        let today = GardenDays.key(now, calendar: calendar)
        let same = gardenDay == today
        var next = self
        next.gardenDay = today
        next.gardenSeconds = same ? gardenSeconds ?? 0 : 0
        next.gardenBonusMinutes = (same ? gardenBonusMinutes ?? 0 : 0) + minutes
        return next
    }
}
