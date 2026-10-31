import Foundation

/// Pips Garten lives in the web app's fields (`garden`, `gardenColumns`,
/// `farmGoods`, `farmXp`, `farmOrders`, `gardenMinutesPerDay`, `gardenDay`,
/// `gardenSeconds`, `gardenBonusMinutes`), in the web app's JSON shapes, so
/// backups move between both apps unchanged. Only the wallet is a native field.
extension ChildProfile {
    /// The web app's id for this child (kept from a backup), else this app's.
    var webID: String {
        webField("id") ?? id.uuidString.lowercased()
    }

    /// The farm, brought up to date like the web app's `normalizeProfile`: old
    /// 6-column gardens are widened, and farms from before levels get their XP.
    var farm: Farm {
        let stored: [GardenPlot?]? = webField("garden")
        let columns: Int? = webField("gardenColumns")
        let garden = Farm.normalized(stored.map { columns != Farm.columns ? Farm.widen($0) : $0 } ?? Farm.emptyGarden())
        let goods: [String: Int] = webField("farmGoods") ?? [:]
        return Farm(
            profileID: webID,
            walletStars: walletStars,
            garden: garden,
            goods: Dictionary(uniqueKeysWithValues: Produce.allCases.map { ($0, goods[$0.rawValue] ?? 0) }),
            xp: webField("farmXp") ?? Farm.startingXp(garden),
            orders: webField("farmOrders")
        )
    }

    /// Stores the farm (save the model context afterwards).
    func setFarm(_ farm: Farm) {
        walletStars = farm.walletStars
        setWebField("garden", farm.garden)
        setWebField("gardenColumns", Farm.columns)
        setWebField("farmGoods", Dictionary(uniqueKeysWithValues: Produce.allCases.map { ($0.rawValue, farm.goods($0)) }))
        setWebField("farmXp", farm.xp)
        setWebField("farmOrders", farm.orders)
    }

    var gardenTime: GardenTime {
        GardenTime(
            minutesPerDay: webField("gardenMinutesPerDay") ?? GardenTime.defaultMinutes,
            day: webField("gardenDay"),
            seconds: webField("gardenSeconds") ?? 0,
            bonusMinutes: webField("gardenBonusMinutes") ?? 0
        )
    }

    /// Stores the time counted today (the daily limit itself is a setting, see `gardenMinutesPerDay`).
    func setGardenTime(_ time: GardenTime) {
        setWebField("gardenDay", time.day)
        setWebField("gardenSeconds", time.seconds)
        setWebField("gardenBonusMinutes", time.bonusMinutes)
    }

    /// Minutes a day in the garden (0 = no limit), set by a grown-up.
    var gardenMinutesPerDay: Int {
        get { webField("gardenMinutesPerDay") ?? GardenTime.defaultMinutes }
        set { setWebField("gardenMinutesPerDay", min(max(newValue, 0), 240)) }
    }
}
