import Foundation

/// An optional birthday, kept as the web field "birthDate" ("YYYY-MM-DD",
/// web/src/domain/profile.ts): the age then goes up by itself.
extension ChildProfile {
    private static let birthDateFormat: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    var birthDate: Date? {
        get { webField("birthDate", as: String.self).flatMap(Self.birthDateFormat.date(from:)) }
        set { setWebField("birthDate", newValue.map(Self.birthDateFormat.string(from:))) }
    }

    /// Full years on `date`.
    static func age(bornOn birthDate: Date, on date: Date = .now, calendar: Calendar = .current) -> Int {
        calendar.dateComponents([.year], from: calendar.startOfDay(for: birthDate), to: date).year ?? 0
    }

    /// A birthday since the last visit: the age goes up by itself. A subject
    /// that was ahead keeps its level (the lead shrinks by the years gained);
    /// the others grow with the child. Returns whether anything changed.
    @discardableResult
    func refreshAgeFromBirthday(now: Date = .now, calendar: Calendar = .current) -> Bool {
        guard let birthDate else { return false }
        let newAge = Self.age(bornOn: birthDate, on: now, calendar: calendar).clamped(to: DifficultyTuning.ageRange)
        guard newAge != age else { return false }
        let gained = Double(newAge - age)
        func shift(_ a: Double) -> Double { gained > 0 && a > 0 ? max(0, a - gained) : a }
        age = newAge
        difficultyAdjustment = shift(difficultyAdjustment)
        for subject in progress {
            if let adjustment = subject.adjustment { subject.adjustment = shift(adjustment) }
        }
        if !DifficultyScale.difficulty(forAge: newAge).allowsGentleTimer {
            gentleTimerEnabled = false
        }
        return true
    }
}
