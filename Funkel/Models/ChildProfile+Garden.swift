import Foundation

/// The farm lives in `backupExtras` under the web app's field names and JSON
/// shapes (web/src/domain/profile.ts), so a backup moves a farm between the
/// two apps unchanged. Only the wallet is a field of its own.
extension ChildProfile {
    /// The id the web app knows this child by.
    var webID: String {
        BackupExtras.decode(backupExtras)["id"] as? String ?? id.uuidString.lowercased()
    }

    /// Minutes a day in Pips Garten (0 = no limit; 20 when never set, like the web app).
    var gardenMinutesPerDay: Int {
        get { webField("gardenMinutesPerDay", as: Int.self) ?? Farm.defaultMinutesPerDay }
        set { setWebField("gardenMinutesPerDay", newValue) }
    }

    /// Reads the farm, filling what older versions didn't store: an old
    /// 6-column garden is widened, and farms built before levels existed
    /// start with the XP of what was spent on them.
    func loadFarm() -> Farm {
        var garden = Garden.empty()
        if let saved = webField("garden", as: Garden.self) {
            garden = webField("gardenColumns", as: Int.self) == Garden.columns ? saved.normalized() : Garden.widened(saved.plots).normalized()
        }
        let goods = webField("farmGoods", as: [String: Int].self) ?? [:]
        var farm = Farm(profileID: webID, walletStars: walletStars, garden: garden)
        for kind in Produce.allCases { farm.goods[kind] = goods[kind.rawValue] ?? 0 }
        farm.xp = webField("farmXp", as: Int.self) ?? garden.startingFarmXp
        farm.orders = webField("farmOrders", as: FarmOrders.self)
        farm.minutesPerDay = gardenMinutesPerDay
        farm.gardenDay = webField("gardenDay", as: String.self)
        farm.gardenSeconds = webField("gardenSeconds", as: Int.self)
        farm.gardenBonusMinutes = webField("gardenBonusMinutes", as: Int.self)
        return farm
    }

    /// Stores the farm (and the wallet). Remember to save the model context.
    func saveFarm(_ farm: Farm) {
        walletStars = farm.walletStars
        var fields = BackupExtras.decode(backupExtras)
        func put<T: Encodable>(_ key: String, _ value: T?) {
            if let value, let json = Self.jsonValue(value) { fields[key] = json } else { fields.removeValue(forKey: key) }
        }
        put("garden", farm.garden)
        put("gardenColumns", Garden.columns)
        put("farmGoods", Dictionary(uniqueKeysWithValues: Produce.allCases.map { ($0.rawValue, farm.goods($0)) }))
        put("farmXp", farm.xp)
        put("farmOrders", farm.orders)
        put("gardenDay", farm.gardenDay)
        put("gardenSeconds", farm.gardenSeconds)
        put("gardenBonusMinutes", farm.gardenBonusMinutes)
        backupExtras = BackupExtras.encode(fields)
    }

    private static func jsonValue<T: Encodable>(_ value: T) -> Any? {
        guard let data = try? JSONEncoder().encode([value]),
              let array = try? JSONSerialization.jsonObject(with: data) as? [Any] else { return nil }
        return array.first
    }
}
