#if DEBUG
import Foundation

/// A lived-in farm for UI tests and screenshots (Debug only): buildings,
/// animals, fields with things ready, roads, fences and a building site.
enum GardenSample {
    @MainActor
    static func fill(_ profile: ChildProfile, now: Date = .now) {
        func daysAgo(_ days: Int) -> String {
            FarmDay.key(Calendar.current.date(byAdding: .day, value: -days, to: now) ?? now)
        }
        var garden = Farm.emptyGarden()
        func put(_ cell: Int, _ id: String, _ age: Int = 10, variant: String? = nil) {
            garden[cell] = GardenPlot(itemId: id, plantedDay: daysAgo(age), variant: variant)
        }
        let c = Farm.columns
        put(0, "tree", variant: "🌲")
        put(15, "tree", variant: "🌳")
        for (i, flower) in ["🌷", "🌻", "🌼"].enumerated() { put(5 + i, "flower", variant: flower) }
        put(c + 1, "farmhouse")
        put(2 * c + 3, "mailbox")
        for row in 0..<3 { put(row * c + 4, "road") }
        for col in 0..<c { put(3 * c + col, "road") }
        put(c + 6, "barn")
        put(c + 8, "cow")
        put(c + 9, "sheep")
        put(2 * c + 8, "horse")
        put(2 * c + 9, "cow", 2)
        put(11, "coop")
        put(12, "chick")
        put(c + 12, "chick")
        put(c + 13, "pond")
        put(2 * c + 13, "duck")
        put(2 * c + 14, "duck")
        put(4 * c + 1, "windmill")
        for col in 3...6 {
            put(4 * c + col, "wheat", 3)
            put(5 * c + col, "wheat", col == 6 ? 0 : 3)
        }
        put(4 * c + 8, "vegetable", 4, variant: "🥕")
        put(4 * c + 9, "vegetable", 4, variant: "🎃")
        put(5 * c + 8, "vegetable", 1, variant: "🥬")
        put(5 * c + 9, "vegetable", 4, variant: "🍅")
        put(4 * c + 11, "beehive")
        put(5 * c + 12, "bee")
        put(4 * c + 13, "appletree")
        put(4 * c + 14, "appletree", 1)
        for col in 3...10 { put(6 * c + col, "fence") }
        put(6 * c + 12, "doghouse", 0)
        for (i, flower) in ["🌸", "🌹", "🪻", "🌻"].enumerated() { put(7 * c + i, "flower", variant: flower) }
        put(7 * c + 6, "tractor")
        put(7 * c + 9, "fountain")
        put(7 * c + 11, "rabbit")

        var farm = profile.farm
        farm.garden = garden
        farm.xp = 400
        farm.goods[.egg] = 4
        farm.goods[.milk] = 2
        farm.goods[.wheat] = 6
        profile.setFarm(farm.withTodaysOrders(now: now))
    }
}
#endif
