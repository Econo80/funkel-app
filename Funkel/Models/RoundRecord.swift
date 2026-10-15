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
    var profile: ChildProfile?

    init(
        date: Date = .now,
        subjectID: String,
        languageCode: String,
        correct: Int,
        total: Int,
        starsEarned: Int,
        effectiveAge: Double,
        profile: ChildProfile? = nil
    ) {
        self.date = date
        self.subjectID = subjectID
        self.languageCode = languageCode
        self.correct = correct
        self.total = total
        self.starsEarned = starsEarned
        self.effectiveAge = effectiveAge
        self.profile = profile
    }
}
