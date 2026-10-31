import Foundation

/// The play corner: stars earned in quizzes can be spent on short games (a
/// ticket) or on Pips Garten. Lifetime stars (`totalStars`) never go down;
/// only the wallet is spent. Mirrors web/src/domain/games.ts.
enum GameID: String, CaseIterable, Identifiable {
    case memory, balloons, stars

    var id: String { rawValue }
}

/// Games are pitched to the child's age, shifted two years either way by a grown-up.
enum GameDifficulty: String, CaseIterable, Identifiable, Codable {
    case easy, normal, hard

    var id: String { rawValue }

    var ageOffset: Int {
        switch self {
        case .easy: -2
        case .normal: 0
        case .hard: 2
        }
    }
}

enum Games {
    /// One ticket lasts this long; then Pip says goodbye.
    static let seconds = 120

    static let costChoices = [5, 10, 15, 20]
    /// 0 = no daily limit.
    static let perDayChoices = [1, 2, 3, 5, 0]
    static let bonusChoices = [1, 2, 3]
    static let maxBonus = 10

    static let costRange = 1...100
    static let perDayRange = 0...20

    /// The age the games are pitched at (independent of the quiz difficulty).
    static func gameAge(age: Int, difficulty: GameDifficulty) -> Int {
        (age + difficulty.ageOffset).clamped(to: 4...14)
    }
}

/// Why a game can or can't start.
enum TicketCheck: Equatable {
    case ok(free: Bool)
    case disabled
    case notEnoughStars(missing: Int)
    case dailyLimit

    var isOK: Bool {
        if case .ok = self { return true }
        return false
    }

    var isFree: Bool { self == .ok(free: true) }
}

/// Everything the play corner needs from a profile, as a value: the
/// settings, today's tickets and bonus games, and the wallet.
/// Read and written with `ChildProfile.playState`.
struct PlayState: Equatable {
    var age: Int
    var walletStars: Int
    var gamesEnabled = true
    var gameCost = 10
    var gamesPerDay = 3
    var gameDifficulty: GameDifficulty = .normal
    /// Day ("YYYY-MM-DD") of the last ticket, and how many tickets were used that day.
    var gameDay: String?
    var gamesToday = 0
    /// Free extra games a grown-up unlocked for `bonusDay` only.
    var bonusGames = 0
    var bonusDay: String?

    var gameAge: Int { Games.gameAge(age: age, difficulty: gameDifficulty) }

    func gamesPlayedToday(_ now: Date, calendar: Calendar = .current) -> Int {
        gameDay == Backup.dayKey(now, calendar: calendar) ? gamesToday : 0
    }

    /// nil = no daily limit.
    func gamesLeftToday(_ now: Date, calendar: Calendar = .current) -> Int? {
        gamesPerDay == 0 ? nil : max(0, gamesPerDay - gamesPlayedToday(now, calendar: calendar))
    }

    /// Extra games a grown-up unlocked for today (free, outside the daily limit).
    func bonusGamesLeftToday(_ now: Date, calendar: Calendar = .current) -> Int {
        bonusDay == Backup.dayKey(now, calendar: calendar) ? bonusGames : 0
    }

    func checkTicket(_ now: Date, calendar: Calendar = .current) -> TicketCheck {
        if !gamesEnabled { return .disabled }
        if bonusGamesLeftToday(now, calendar: calendar) > 0 { return .ok(free: true) }
        if gamesPerDay > 0 && gamesPlayedToday(now, calendar: calendar) >= gamesPerDay { return .dailyLimit }
        if walletStars < gameCost { return .notEnoughStars(missing: gameCost - walletStars) }
        return .ok(free: false)
    }

    /// Spends one ticket: a bonus game first (free), otherwise stars. Unchanged if not allowed.
    func buyingTicket(_ now: Date, calendar: Calendar = .current) -> PlayState {
        let today = Backup.dayKey(now, calendar: calendar)
        var next = self
        switch checkTicket(now, calendar: calendar) {
        case .ok(free: true):
            next.bonusGames = bonusGamesLeftToday(now, calendar: calendar) - 1
            next.bonusDay = today
        case .ok(free: false):
            next.walletStars -= gameCost
            next.gamesToday = gamesPlayedToday(now, calendar: calendar) + 1
            next.gameDay = today
        default:
            break
        }
        return next
    }

    /// Grown-up override: unlock extra free games for today only (capped).
    func grantingBonusGames(_ count: Int, now: Date, calendar: Calendar = .current) -> PlayState {
        var next = self
        next.bonusGames = min(Games.maxBonus, bonusGamesLeftToday(now, calendar: calendar) + max(0, count))
        next.bonusDay = Backup.dayKey(now, calendar: calendar)
        return next
    }
}

// MARK: - Memory

struct MemoryCard: Identifiable, Equatable {
    let id: Int
    let picture: String
}

enum Memory {
    static let pictures = [
        "🐶", "🐱", "🐭", "🐰", "🦊", "🐻", "🐼", "🐨", "🐯", "🦁", "🐮", "🐷", "🐸", "🐵", "🐔",
        "🐧", "🦋", "🐢", "🐙", "🦄", "🍎", "🍌", "🍓", "🍒", "🥕", "🌻", "🚗", "🚀", "🎈", "🧸",
    ]

    /// Each cleared board adds this many pairs, up to `maxPairs`.
    static let growth = 2
    static let maxPairs = 15

    /// Starting board size.
    static func pairs(forAge age: Int) -> Int {
        switch age {
        case ...4: 4
        case 5: 6
        case 6...7: 8
        case 8...10: 10
        default: 12
        }
    }

    /// - Parameter boardsCleared: boards already solved this game; the board grows with each.
    static func board<R: RandomNumberGenerator>(age: Int, boardsCleared: Int = 0, using rng: inout R) -> [MemoryCard] {
        let count = min(maxPairs, pairs(forAge: age) + boardsCleared * growth)
        let chosen = Array(pictures.shuffled(using: &rng).prefix(count))
        return (chosen + chosen).shuffled(using: &rng).enumerated().map { MemoryCard(id: $0.offset, picture: $0.element) }
    }
}

// MARK: - Ballon-Pop

/// Four colours that are easy to tell apart and to name.
enum BalloonColor: String, CaseIterable {
    case red, yellow, blue, green

    var hex: String {
        switch self {
        case .red: "#F0453A"
        case .yellow: "#FFC21A"
        case .blue: "#3D8BFF"
        case .green: "#2FBF60"
        }
    }
}

enum BalloonRule: Equatable {
    case all
    case color(BalloonColor)
    case even
    case product(target: Int)
}

struct BalloonSpec: Equatable {
    var label: String?
    var color: BalloonColor?
    var good: Bool
}

enum Balloons {
    /// The target colour switches this often, so the child has to keep watching.
    static let colorSeconds = 30.0
    static let productTargets = [12, 18, 24, 36]

    /// The youngest pop everything, then by colour; older children pop by a maths rule.
    static func rule<R: RandomNumberGenerator>(forAge age: Int, using rng: inout R) -> BalloonRule {
        if age < 5 { return .all }
        if age < 7 { return .color(BalloonColor.allCases.randomElement(using: &rng) ?? .red) }
        if age < 9 { return .even }
        return .product(target: productTargets.randomElement(using: &rng) ?? 24)
    }

    /// The next colour rule: always a different colour from the current one.
    static func nextColor<R: RandomNumberGenerator>(after current: BalloonColor, using rng: inout R) -> BalloonColor {
        BalloonColor.allCases.filter { $0 != current }.randomElement(using: &rng) ?? current
    }

    static func spawn<R: RandomNumberGenerator>(_ rule: BalloonRule, using rng: inout R) -> BalloonSpec {
        switch rule {
        case .all:
            return BalloonSpec(good: true)
        case .color(let target):
            let color = Double.random(in: 0..<1, using: &rng) < 0.4
                ? target
                : BalloonColor.allCases.filter { $0 != target }.randomElement(using: &rng) ?? target
            return BalloonSpec(color: color, good: color == target)
        case .even:
            let n = Int.random(in: 1...20, using: &rng)
            return BalloonSpec(label: String(n), good: n.isMultiple(of: 2))
        case .product(let target):
            let factors = (2...9).filter { target % $0 == 0 && target / $0 <= 12 }.map { ($0, target / $0) }
            if Double.random(in: 0..<1, using: &rng) < 0.45, let pair = factors.randomElement(using: &rng) {
                return BalloonSpec(label: "\(pair.0)·\(pair.1)", good: true)
            }
            // A near miss that isn't the target.
            var a: Int, b: Int
            repeat {
                a = Int.random(in: 2...9, using: &rng)
                b = Int.random(in: 2...9, using: &rng)
            } while a * b == target
            return BalloonSpec(label: "\(a)·\(b)", good: false)
        }
    }
}
