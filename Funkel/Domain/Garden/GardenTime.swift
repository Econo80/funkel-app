import Foundation

/// The daily time limit in Pips Garten (web/src/domain/profile.ts): a grown-up
/// sets minutes per day (0 = no limit) and can give extra minutes for today.
struct GardenTime: Equatable {
    static let minutesChoices = [10, 15, 20, 30, 45, 0]
    static let defaultMinutes = 20
    static let bonusChoices = [5, 10, 15]

    /// Minutes a day in the garden (0 = no limit).
    var minutesPerDay = GardenTime.defaultMinutes
    /// Time spent in the garden on `day`, and extra minutes a grown-up gave for that day.
    var day: String?
    var seconds = 0
    var bonusMinutes = 0

    /// Seconds of garden time left today, or nil when there's no limit.
    func secondsLeft(now: Date) -> Int? {
        guard minutesPerDay > 0 else { return nil }
        let today = day == FarmDay.key(now)
        let allowed = (minutesPerDay + (today ? bonusMinutes : 0)) * 60
        return max(0, allowed - (today ? seconds : 0))
    }

    /// Counts time spent in the garden (a new day starts from zero).
    func adding(seconds extra: Int, now: Date) -> GardenTime {
        guard extra > 0 else { return self }
        let today = FarmDay.key(now)
        let same = day == today
        var time = self
        time.day = today
        time.seconds = (same ? seconds : 0) + extra
        time.bonusMinutes = same ? bonusMinutes : 0
        return time
    }

    /// A grown-up gives extra garden minutes, for today only.
    func granting(minutes: Int, now: Date) -> GardenTime {
        let today = FarmDay.key(now)
        let same = day == today
        var time = self
        time.day = today
        time.seconds = same ? seconds : 0
        time.bonusMinutes = (same ? bonusMinutes : 0) + minutes
        return time
    }
}
