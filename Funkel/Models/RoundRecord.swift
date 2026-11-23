import Foundation
import SwiftData

/// One finished round, kept for the grown-up area's history view.
@Model
final class RoundRecord {
    var date: Date
    var subjectID: String
    var languageCode: String
    var correct: Int
    var total: Int
    var starsEarned: Int
    var effectiveAge: Double
    /// How each kind of question went: `["addition": [right, asked]]`, for the
    /// weekly overview. Empty for rounds from before 21 Nov 2026. The default
    /// keeps SwiftData's lightweight migration working for older stores.
    var skillStats: [String: [Int]] = [:]
    var profile: ChildProfile?

    init(
        date: Date = .now,
        subjectID: String,
        languageCode: String,
        correct: Int,
        total: Int,
        starsEarned: Int,
        effectiveAge: Double,
        skillStats: [String: [Int]] = [:],
        profile: ChildProfile? = nil
    ) {
        self.date = date
        self.subjectID = subjectID
        self.languageCode = languageCode
        self.correct = correct
        self.total = total
        self.starsEarned = starsEarned
        self.effectiveAge = effectiveAge
        self.skillStats = skillStats
        self.profile = profile
    }
}
