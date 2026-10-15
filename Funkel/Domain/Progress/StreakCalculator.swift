import Foundation

/// Calendar-day streaks. Playing any round on a day counts for that day.
enum StreakCalculator {

    struct Result: Equatable {
        let current: Int
        let longest: Int
        let lastPlayedDay: Date
    }

    static func update(
        current: Int,
        longest: Int,
        lastPlayedDay: Date?,
        playedAt now: Date,
        calendar: Calendar = .current
    ) -> Result {
        let today = calendar.startOfDay(for: now)

        let newCurrent: Int
        if let last = lastPlayedDay.map(calendar.startOfDay(for:)) {
            let days = calendar.dateComponents([.day], from: last, to: today).day ?? 0
            switch days {
            case ..<1: newCurrent = max(current, 1)   // same day (or clock moved back)
            case 1: newCurrent = current + 1          // consecutive day
            default: newCurrent = 1                   // streak broken, start again
            }
        } else {
            newCurrent = 1
        }

        return Result(current: newCurrent, longest: max(longest, newCurrent), lastPlayedDay: today)
    }

    /// The streak to *display* — a streak whose last day is before yesterday has lapsed.
    static func displayedStreak(current: Int, lastPlayedDay: Date?, now: Date, calendar: Calendar = .current) -> Int {
        guard let last = lastPlayedDay else { return 0 }
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: last), to: calendar.startOfDay(for: now)).day ?? 0
        return days <= 1 ? current : 0
    }
}
