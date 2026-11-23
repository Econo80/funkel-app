import Foundation

/// The weekly overview for grown-ups (mirrors web/src/domain/weekly.ts): the
/// last seven days (today included) next to the seven before, per subject, and
/// which kinds of questions went well or need practice. Built from the round
/// history only; nothing new is collected except, per round, how each kind of
/// question went (`RoundRecord.skillStats`).
struct WeeklySummary: Equatable {
    static let weekDays = 7
    /// A kind of question needs this many answers in the week before it counts as strong or for practice.
    static let skillMinAnswers = 4
    /// Below this share right: worth practising. At or above `strongShare`: going well.
    static let practiceShare = 0.75
    static let strongShare = 0.9

    /// One finished round, as a value (so the summary needs no SwiftData).
    struct Round: Equatable {
        var date: Date
        var subjectID: String
        var languageCode: String
        var correct: Int
        var total: Int
        var starsEarned: Int
        var effectiveAge: Double
        /// `[skill: [right, asked]]`; empty for older rounds.
        var skills: [String: [Int]] = [:]
    }

    struct Totals: Equatable {
        var daysLearned = 0
        var rounds = 0
        var questions = 0
        var correct = 0
        var stars = 0
    }

    struct SubjectWeek: Equatable, Identifiable {
        let subjectID: String
        let languageCode: String
        var rounds: Int
        var questions: Int
        var correct: Int
        /// Effective age at the first and last round of the week (the level then).
        var levelStart: Double
        var levelEnd: Double

        var id: String { "\(languageCode)/\(subjectID)" }
    }

    struct SkillWeek: Equatable, Identifiable {
        let subjectID: String
        let skill: String
        var correct: Int
        var asked: Int

        var id: String { "\(subjectID):\(skill)" }
        var share: Double { asked == 0 ? 0 : Double(correct) / Double(asked) }
    }

    /// The days, as "YYYY-MM-DD", oldest first; the last one is today.
    let days: [String]
    /// A moment in each of those days (for weekday labels), same order.
    let dates: [Date]
    /// Rounds per day, same order.
    let dayRounds: [Int]
    let week: Totals
    let previous: Totals
    /// Sorted by rounds, most first.
    let subjects: [SubjectWeek]
    let strong: [SkillWeek]
    let practice: [SkillWeek]

    init(rounds: [Round], now: Date = .now, calendar: Calendar = .current) {
        func shifted(_ days: Int) -> Date {
            calendar.date(byAdding: .day, value: days, to: now) ?? now
        }
        let dates = (0..<Self.weekDays).map { shifted($0 - (Self.weekDays - 1)) }
        let days = dates.map { Backup.dayKey($0, calendar: calendar) }
        let earlier = Set((0..<Self.weekDays).map { Backup.dayKey(shifted($0 - (2 * Self.weekDays - 1)), calendar: calendar) })
        let thisWeekDays = Set(days)
        func dayOf(_ round: Round) -> String { Backup.dayKey(round.date, calendar: calendar) }

        // Stable, like JavaScript's sort.
        let sorted = Self.stableSorted(rounds) { a, b in
            a.date == b.date ? nil : a.date < b.date
        }
        let thisWeek = sorted.filter { thisWeekDays.contains(dayOf($0)) }
        let lastWeek = sorted.filter { earlier.contains(dayOf($0)) }

        var subjects: [SubjectWeek] = []
        var skills: [SkillWeek] = []
        for round in thisWeek {
            let key = "\(round.languageCode)/\(round.subjectID)"
            if let i = subjects.firstIndex(where: { $0.id == key }) {
                subjects[i].rounds += 1
                subjects[i].questions += round.total
                subjects[i].correct += round.correct
                subjects[i].levelEnd = round.effectiveAge
            } else {
                subjects.append(SubjectWeek(
                    subjectID: round.subjectID,
                    languageCode: round.languageCode,
                    rounds: 1,
                    questions: round.total,
                    correct: round.correct,
                    levelStart: round.effectiveAge,
                    levelEnd: round.effectiveAge
                ))
            }
            // A dictionary has no order; by name, so ties always sort the same way.
            for skill in round.skills.keys.sorted() {
                guard let pair = round.skills[skill], pair.count == 2 else { continue }
                let id = "\(round.subjectID):\(skill)"
                if let i = skills.firstIndex(where: { $0.id == id }) {
                    skills[i].correct += pair[0]
                    skills[i].asked += pair[1]
                } else {
                    skills.append(SkillWeek(subjectID: round.subjectID, skill: skill, correct: pair[0], asked: pair[1]))
                }
            }
        }

        let counted = skills.filter { $0.asked >= Self.skillMinAnswers }
        let practice = Self.stableSorted(counted.filter { $0.share < Self.practiceShare }) { a, b in
            if a.share != b.share { return a.share < b.share }
            if a.asked != b.asked { return a.asked > b.asked }
            return nil
        }
        let strong = Self.stableSorted(counted.filter { $0.share >= Self.strongShare }) { a, b in
            if a.share != b.share { return a.share > b.share }
            if a.asked != b.asked { return a.asked > b.asked }
            return nil
        }

        self.days = days
        self.dates = dates
        self.dayRounds = days.map { day in thisWeek.filter { dayOf($0) == day }.count }
        self.week = Self.totals(thisWeek, calendar: calendar)
        self.previous = Self.totals(lastWeek, calendar: calendar)
        self.subjects = Self.stableSorted(subjects) { a, b in
            a.rounds == b.rounds ? nil : a.rounds > b.rounds
        }
        self.strong = Array(strong.prefix(3))
        self.practice = Array(practice.prefix(3))
    }

    /// A child's week, from the saved round history.
    init(profile: ChildProfile, now: Date = .now, calendar: Calendar = .current) {
        self.init(rounds: profile.rounds.map(Round.init(record:)), now: now, calendar: calendar)
    }

    /// How each kind of question went in one round: `[skill: [right, asked]]`.
    /// Questions without a kind and questions not answered are left out.
    static func skillTally(_ skills: [String?], _ results: [Bool]) -> [String: [Int]] {
        var tally: [String: [Int]] = [:]
        for (i, right) in results.enumerated() {
            guard skills.indices.contains(i), let skill = skills[i], !skill.isEmpty else { continue }
            let before = tally[skill] ?? [0, 0]
            tally[skill] = [before[0] + (right ? 1 : 0), before[1] + 1]
        }
        return tally
    }

    /// Share right as a whole percentage, 0 when nothing was asked.
    static func percent(_ correct: Int, of asked: Int) -> Int {
        asked == 0 ? 0 : Int((100 * Double(correct) / Double(asked)).rounded())
    }

    private static func totals(_ rounds: [Round], calendar: Calendar) -> Totals {
        Totals(
            daysLearned: Set(rounds.map { Backup.dayKey($0.date, calendar: calendar) }).count,
            rounds: rounds.count,
            questions: rounds.reduce(0) { $0 + $1.total },
            correct: rounds.reduce(0) { $0 + $1.correct },
            stars: rounds.reduce(0) { $0 + $1.starsEarned }
        )
    }

    /// Sorts by `isBefore` (nil when equal), keeping the original order for ties.
    private static func stableSorted<T>(_ items: [T], by isBefore: (T, T) -> Bool?) -> [T] {
        items.enumerated()
            .sorted { a, b in isBefore(a.element, b.element) ?? (a.offset < b.offset) }
            .map(\.element)
    }
}

extension WeeklySummary.Round {
    init(record: RoundRecord) {
        self.init(
            date: record.date,
            subjectID: record.subjectID,
            languageCode: record.languageCode,
            correct: record.correct,
            total: record.total,
            starsEarned: record.starsEarned,
            effectiveAge: record.effectiveAge,
            skills: record.skillStats
        )
    }
}
