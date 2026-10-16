import SwiftData
import XCTest
@testable import Funkel

final class GrownUpsTests: XCTestCase {

    // MARK: Gate

    func testGateQuestionsAreTwoDigitTimesOneDigit() {
        var rng = SeededGenerator(seed: 21)
        for _ in 0..<500 {
            let c = GateChallenge.random(using: &rng)
            XCTAssertTrue(GateChallenge.firstFactorRange.contains(c.a))
            XCTAssertTrue(GateChallenge.secondFactorRange.contains(c.b))
            XCTAssertGreaterThanOrEqual(c.answer, 36, "never trivial")
        }
    }

    func testGateChecksTheAnswer() {
        let c = GateChallenge(a: 14, b: 7)
        XCTAssertTrue(c.isCorrect("98"))
        XCTAssertTrue(c.isCorrect(" 98 "))
        XCTAssertFalse(c.isCorrect("97"))
        XCTAssertFalse(c.isCorrect(""))
    }

    // MARK: Settings

    private let all = ["maths", "vocabulary", "generalKnowledge"]

    func testSubjectTogglesKeepAtLeastOneAndStoreAllAsEmpty() {
        var s = ProfileSettings()
        XCTAssertTrue(all.allSatisfy { s.isSubjectEnabled($0) })

        s.setSubject("maths", enabled: false, available: all)
        XCTAssertEqual(s.enabledSubjectIDs, ["vocabulary", "generalKnowledge"])
        s.setSubject("vocabulary", enabled: false, available: all)
        XCTAssertTrue(s.isLastEnabledSubject("generalKnowledge", available: all))
        s.setSubject("generalKnowledge", enabled: false, available: all)
        XCTAssertEqual(s.enabledSubjectIDs, ["generalKnowledge"], "the last subject can't be switched off")

        s.setSubject("maths", enabled: true, available: all)
        s.setSubject("vocabulary", enabled: true, available: all)
        XCTAssertEqual(s.enabledSubjectIDs, [], "all on is stored as 'all', so new subjects appear automatically")
    }

    func testChangingLanguageTurnsAllSubjectsOn() {
        var s = ProfileSettings()
        s.setSubject("maths", enabled: false, available: all)
        s.setLearningLanguage("fr")
        XCTAssertEqual(s.learningLanguage, "fr")
        XCTAssertEqual(s.enabledSubjectIDs, [])
    }

    func testApplyWritesBackAndRespectsAgeRules() {
        let profile = ChildProfile(name: "Emil", age: 10)
        profile.difficultyAdjustment = 0.9
        var s = ProfileSettings(profile: profile)
        XCTAssertEqual(s.name, "Emil")

        s.name = "  Emilio "
        s.gentleTimerEnabled = true
        s.roundLength = 15
        s.readAloudEnabled = false
        s.apply(to: profile)
        XCTAssertEqual(profile.name, "Emilio")
        XCTAssertTrue(profile.gentleTimerEnabled)
        XCTAssertEqual(profile.roundLength, 15)
        XCTAssertFalse(profile.readAloudEnabled)
        XCTAssertEqual(profile.difficultyAdjustment, 0.9, "same age keeps adaptivity")

        s.age = 7
        XCTAssertFalse(s.allowsGentleTimer)
        s.apply(to: profile)
        XCTAssertEqual(profile.age, 7)
        XCTAssertEqual(profile.difficultyAdjustment, 0, "a new age resets adaptivity")
        XCTAssertFalse(profile.gentleTimerEnabled, "no timer below 9")
    }

    func testNameIsRequired() {
        var s = ProfileSettings()
        s.name = "   "
        XCTAssertFalse(s.isValid)
        s.name = "Ida"
        XCTAssertTrue(s.isValid)
        XCTAssertEqual(s.makeProfile().name, "Ida")
    }

    // MARK: Maintenance

    private func context() throws -> ModelContext {
        let container = try ModelContainer(
            for: ChildProfile.self, SubjectProgress.self, RoundRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return ModelContext(container)
    }

    func testResetClearsProgressButKeepsTheProfile() throws {
        let context = try context()
        let profile = ChildProfile(name: "Lena", age: 5)
        context.insert(profile)
        let outcome = RoundOutcome(subjectID: "maths", languageCode: "de", correct: 9, total: 10, correctContentIDs: [], effectiveAge: 5)
        ProgressRecorder(context: context).record(outcome, for: profile)
        XCTAssertEqual(profile.totalStars, 9)

        ProfileMaintenance.resetProgress(of: profile, in: context)
        XCTAssertEqual(profile.totalStars, 0)
        XCTAssertEqual(profile.currentStreak, 0)
        XCTAssertNil(profile.lastPlayedDay)
        XCTAssertTrue(profile.progress.isEmpty)
        XCTAssertTrue(profile.rounds.isEmpty)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<SubjectProgress>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<RoundRecord>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<ChildProfile>()), 1)
    }

    func testDeleteRemovesProfileAndItsData() throws {
        let context = try context()
        let profile = ChildProfile(name: "Finn", age: 8)
        context.insert(profile)
        let outcome = RoundOutcome(subjectID: "maths", languageCode: "de", correct: 5, total: 10, correctContentIDs: [], effectiveAge: 8)
        ProgressRecorder(context: context).record(outcome, for: profile)

        ProfileMaintenance.delete(profile, in: context)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<ChildProfile>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<SubjectProgress>()), 0, "cascade")
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<RoundRecord>()), 0, "cascade")
    }
}
