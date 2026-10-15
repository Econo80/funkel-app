import Foundation
import SwiftData

/// Cumulative progress for one subject in one learning language.
@Model
final class SubjectProgress {
    var subjectID: String
    var languageCode: String
    var roundsPlayed: Int
    var questionsAnswered: Int
    var correctAnswers: Int
    var stars: Int
    var lastPlayed: Date?
    /// Content ids answered correctly in the last few rounds, newest last.
    /// Used to down-weight repeats (PLAN.md §5.3).
    var recentCorrectContentIDs: [String]
    var profile: ChildProfile?

    init(subjectID: String, languageCode: String, profile: ChildProfile? = nil) {
        self.subjectID = subjectID
        self.languageCode = languageCode
        self.roundsPlayed = 0
        self.questionsAnswered = 0
        self.correctAnswers = 0
        self.stars = 0
        self.lastPlayed = nil
        self.recentCorrectContentIDs = []
        self.profile = profile
    }

    var accuracy: Double {
        questionsAnswered == 0 ? 0 : Double(correctAnswers) / Double(questionsAnswered)
    }
}
