import Foundation

/// One thing on the farm, stored at its top-left square, in the web app's
/// JSON shape: `{ itemId, plantedDay, variant?, collectedDay? }`.
struct GardenPlot: Codable, Equatable {
    var itemID: String
    /// Day key ("YYYY-MM-DD") it was placed (or last harvested).
    var plantedDay: String
    var variant: String? = nil
    /// Last day the daily gift (egg, milk, honey, apples) was collected.
    var collectedDay: String? = nil

    enum CodingKeys: String, CodingKey {
        case itemID = "itemId", plantedDay, variant, collectedDay
    }

    var item: GardenItem? { GardenCatalog.item(itemID) }
}

/// The meadow: 16 columns, row by row; `nil` is a free square (or one
/// covered by a bigger item whose anchor is further up or left).
/// Stored as a JSON array of plots and `null`s, like the web app.
struct Garden: Equatable, Codable {
    var plots: [GardenPlot?]

    /// Wider than a screen: the garden scrolls.
    static let columns = 16
    static let startRows = 8
    static let startSize = columns * startRows
    /// Each purchase adds four rows.
    static let rowsPerPurchase = 4
    static let landPrices = [25, 40, 60]

    /// Gardens saved before the farm was widened were 6 columns wide, 4 rows plus 2 per land purchase.
    static let legacyColumns = 6
    private static let legacyStartRows = 4
    private static let legacyRowsPerPurchase = 2

    init(plots: [GardenPlot?]) { self.plots = plots }

    static func empty() -> Garden { Garden(plots: Array(repeating: nil, count: startSize)) }

    subscript(cell: Int) -> GardenPlot? {
        get { plots.indices.contains(cell) ? plots[cell] : nil }
        set { if plots.indices.contains(cell) { plots[cell] = newValue } }
    }

    var count: Int { plots.count }
    var rows: Int { (plots.count + Self.columns - 1) / Self.columns }

    // MARK: Codable (a plain array; a plot that can't be read becomes a free square)

    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        var plots: [GardenPlot?] = []
        while !container.isAtEnd {
            plots.append(try container.decode(LenientPlot.self).plot)
        }
        self.plots = plots
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(plots)
    }

    private struct LenientPlot: Decodable {
        let plot: GardenPlot?
        init(from decoder: Decoder) throws {
            plot = try? decoder.singleValueContainer().decode(GardenPlot.self)
        }
    }

    // MARK: Shape

    /// At least the starting size, in whole rows.
    func normalized() -> Garden {
        var plots = self.plots
        let size = max(Self.startSize, rows * Self.columns)
        while plots.count < size { plots.append(nil) }
        return Garden(plots: plots)
    }

    /// Moves an old 6-column garden into the wide one: everything keeps its row and
    /// column, and each piece of land bought earlier still counts as one purchase.
    static func widened(_ old: [GardenPlot?]) -> Garden {
        let oldRows = (old.count + legacyColumns - 1) / legacyColumns
        let purchases = max(0, (oldRows - legacyStartRows + legacyRowsPerPurchase - 1) / legacyRowsPerPurchase)
        let rows = startRows + min(purchases, landPrices.count) * rowsPerPurchase
        var garden = Array<GardenPlot?>(repeating: nil, count: rows * columns)
        for (i, plot) in old.enumerated() {
            guard let plot else { continue }
            let target = (i / legacyColumns) * columns + i % legacyColumns
            if garden.indices.contains(target) { garden[target] = plot }
        }
        return Garden(plots: garden)
    }

    /// Price of the next piece of land, or nil when the garden is as big as it gets.
    var nextLandPrice: Int? {
        let bought = (rows - Self.startRows) / Self.rowsPerPurchase
        return Self.landPrices.indices.contains(bought) ? Self.landPrices[bought] : nil
    }

    /// XP for farms built before levels existed: what was spent on them.
    var startingFarmXp: Int {
        let items = plots.reduce(0) { $0 + ($1?.item?.price ?? 0) }
        let purchases = max(0, (rows - Self.startRows) / Self.rowsPerPurchase)
        let land = Self.landPrices.prefix(purchases).reduce(0, +)
        return items + land
    }

    // MARK: Layout

    /// For each square, the anchor of the item covering it (an item's top-left square is its anchor).
    func occupancy() -> [Int?] {
        var covered = Array<Int?>(repeating: nil, count: plots.count)
        for (anchor, plot) in plots.enumerated() {
            guard let item = plot?.item else { continue }
            let col = anchor % Self.columns, row = anchor / Self.columns
            for r in row..<(row + item.height) {
                for c in col..<(col + item.width) where c < Self.columns {
                    let cell = r * Self.columns + c
                    if covered.indices.contains(cell) { covered[cell] = anchor }
                }
            }
        }
        return covered
    }

    /// Where a big item goes when this square is tapped: shifted left/up so it fits the grid.
    func anchor(for cell: Int, item: GardenItem) -> Int {
        let col = min(cell % Self.columns, Self.columns - item.width)
        let row = min(cell / Self.columns, rows - item.height)
        return row * Self.columns + col
    }

    func fits(_ item: GardenItem, at anchor: Int, ignoring ignored: Int? = nil) -> Bool {
        let col = anchor % Self.columns, row = anchor / Self.columns
        guard anchor >= 0, col + item.width <= Self.columns, row + item.height <= rows else { return false }
        let covered = occupancy()
        for r in row..<(row + item.height) {
            for c in col..<(col + item.width) {
                let index = r * Self.columns + c
                guard covered.indices.contains(index) else { return false }
                if let owner = covered[index], owner != ignored { return false }
            }
        }
        return true
    }

    struct Links: Equatable {
        var n = false, e = false, s = false, w = false
        var any: Bool { n || e || s || w }
    }

    /// Which neighbours (up, right, down, left) hold the same road, path or fence.
    func connections(at cell: Int) -> Links {
        let id = self[cell]?.itemID
        func same(_ i: Int) -> Bool { i >= 0 && i < plots.count && plots[i]?.itemID == id }
        let col = cell % Self.columns
        return Links(
            n: same(cell - Self.columns),
            e: col < Self.columns - 1 && same(cell + 1),
            s: same(cell + Self.columns),
            w: col > 0 && same(cell - 1)
        )
    }

    // MARK: Homes

    struct HomeSpace: Equatable {
        var capacity = 0
        var used = 0
    }

    /// Places for this kind of animal in finished homes, and how many are taken.
    func homeSpace(_ group: HomeGroup, now: Date, calendar: Calendar = .current) -> HomeSpace {
        var space = HomeSpace()
        for case let plot? in plots {
            guard let item = plot.item else { continue }
            if item.houses == group && plot.isGrown(now: now, calendar: calendar) { space.capacity += item.capacity }
            if item.needs == group { space.used += 1 }
        }
        return space
    }

    // MARK: Goods

    /// Every square with something ready, one per item.
    func readyCells(now: Date, calendar: Calendar = .current) -> [Int] {
        plots.indices.filter { plots[$0]?.readyProduce(now: now, calendar: calendar) != nil }
    }

    /// Goods this farm can make: from what's on it, grown or not.
    var producibleGoods: [Produce] {
        let kinds = Set(plots.compactMap { $0?.item.flatMap { $0.produce ?? $0.harvest } })
        return Produce.allCases.filter(kinds.contains)
    }
}

// MARK: - Time

enum GardenDays {
    /// Local calendar day, "YYYY-MM-DD", like the web app's `dayKey`.
    static func key(_ date: Date, calendar: Calendar = .current) -> String {
        Backup.dayKey(date, calendar: calendar)
    }

    /// Whole days between a day key and today (calendar days, not 24-hour spans).
    static func since(_ from: String, now: Date, calendar: Calendar = .current) -> Int {
        guard let start = serial(from), let today = serial(key(now, calendar: calendar)) else { return 0 }
        return today - start
    }

    /// Days since 1970-01-01 for a "YYYY-MM-DD" key, independent of time zones.
    private static func serial(_ key: String) -> Int? {
        let parts = key.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC")!
        guard let date = utc.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2])) else { return nil }
        return Int((date.timeIntervalSince1970 / 86_400).rounded())
    }
}

extension GardenPlot {
    func stageIndex(now: Date, calendar: Calendar = .current) -> Int {
        guard let item else { return 0 }
        let age = GardenDays.since(plantedDay, now: now, calendar: calendar)
        var stage = 0
        for (i, day) in item.days.enumerated() where age >= day { stage = i }
        return stage
    }

    func isGrown(now: Date, calendar: Calendar = .current) -> Bool {
        guard let item else { return false }
        return stageIndex(now: now, calendar: calendar) == item.stages.count - 1
    }

    /// The picture this plot shows today: an emoji, or "art:<id>" for a drawn one.
    func picture(now: Date, calendar: Calendar = .current) -> String {
        guard let item else { return "" }
        let stage = stageIndex(now: now, calendar: calendar)
        if stage == item.stages.count - 1, let variant { return variant }
        return item.stages[stage]
    }

    /// Days until the next stage (growing, or a building being finished), or nil when done.
    func daysUntilNextStage(now: Date, calendar: Calendar = .current) -> Int? {
        guard let item else { return nil }
        let age = GardenDays.since(plantedDay, now: now, calendar: calendar)
        return item.days.first { $0 > age }.map { $0 - age }
    }

    func isUnderConstruction(now: Date, calendar: Calendar = .current) -> Bool {
        picture(now: now, calendar: calendar) == GardenCatalog.building
    }

    /// What a plot has ready: grown crops can be harvested (then they grow again);
    /// hens, cows, bees and apple trees give something once a day, from the day
    /// after they arrived.
    func readyProduce(now: Date, calendar: Calendar = .current) -> Produce? {
        guard let item, isGrown(now: now, calendar: calendar) else { return nil }
        if let harvest = item.harvest { return harvest }
        guard let produce = item.produce, GardenDays.since(plantedDay, now: now, calendar: calendar) >= 1 else { return nil }
        return collectedDay == GardenDays.key(now, calendar: calendar) ? nil : produce
    }
}
