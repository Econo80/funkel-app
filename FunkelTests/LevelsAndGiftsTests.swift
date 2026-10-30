import SwiftData
import XCTest
@testable import Funkel

/// Mirrors web/tests/difficulty.test.ts and profile-and-round.test.ts (levels, gifts).
@MainActor
final class LevelsAndGiftsTests: XCTestCase {

    private func makeContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: ChildProfile.self, SubjectProgress.self, RoundRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return ModelContext(container)
    }

    private func perfect(_ subjectID: String) -> RoundOutcome {
        RoundOutcome(subjectID: subjectID, languageCode: "de", correct: 10, total: 10, correctContentIDs: [], effectiveAge: 5)
    }

    // MARK: Adaptivity

    func testStepsUpFasterAfterTwoPerfectRoundsInARow() {
        var a = Adaptivity(adjustment: 0, perfectRounds: 0)
        var steps: [Double] = []
        for round in 0..<8 {
            let (next, boosted) = DifficultyScale.nextAdaptivity(a, correct: 10, total: 10)
            XCTAssertEqual(boosted, round >= 1 && a.adjustment < 3, "round \(round)")
            a = next
            steps.append(a.adjustment)
        }
        XCTAssertEqual(steps[0], 0.15, accuracy: 0.0001)
        XCTAssertEqual(steps[1], 0.65, accuracy: 0.0001)
        XCTAssertEqual(steps[2], 1.15, accuracy: 0.0001)
        XCTAssertEqual(a.adjustment, 3)
        XCTAssertEqual(DifficultyScale.difficulty(forAge: 5, adjustment: a.adjustment).effectiveAge, 8)
    }

    func testAMistakeEndsTheRunAndAHardRoundStepsDown() {
        let nine = DifficultyScale.nextAdaptivity(Adaptivity(adjustment: 1, perfectRounds: 3), correct: 9, total: 10)
        XCTAssertFalse(nine.boosted)
        XCTAssertEqual(nine.adaptivity.perfectRounds, 0)
        XCTAssertEqual(nine.adaptivity.adjustment, 1.15, accuracy: 0.0001)
        XCTAssertFalse(DifficultyScale.nextAdaptivity(nine.adaptivity, correct: 10, total: 10).boosted)

        let hard = DifficultyScale.nextAdaptivity(Adaptivity(adjustment: 2, perfectRounds: 4), correct: 4, total: 10)
        XCTAssertEqual(hard.adaptivity.adjustment, 1.7, accuracy: 0.0001)
        XCTAssertEqual(hard.adaptivity.perfectRounds, 0)
    }

    func testEachSubjectKeepsItsOwnLevel() throws {
        let context = try makeContext()
        let profile = ChildProfile(name: "Lena", age: 5)
        profile.difficultyAdjustment = 0.3
        context.insert(profile)
        // Subjects without their own level start from the old shared one.
        XCTAssertEqual(profile.adaptivity(for: "maths", language: "de").adjustment, 0.3)

        let recorder = ProgressRecorder(context: context)
        var summary: RoundSummary?
        for _ in 0..<3 { summary = recorder.record(perfect("maths"), for: profile) }
        XCTAssertEqual(summary?.levelUp, true)
        let maths = profile.adaptivity(for: "maths", language: "de")
        XCTAssertEqual(maths.adjustment, 0.3 + 0.15 + 0.5 + 0.5, accuracy: 0.0001)
        XCTAssertEqual(maths.perfectRounds, 3)
        XCTAssertEqual(profile.levelAge(for: "maths", language: "de"), 6.45, accuracy: 0.0001)
        XCTAssertEqual(profile.difficulty(for: "maths", language: "de").effectiveAge, 6.45, accuracy: 0.0001)
        XCTAssertEqual(profile.adaptivity(for: "vocabulary", language: "de").adjustment, 0.3)

        // A new age starts every subject from the real age again.
        profile.setAge(6)
        XCTAssertEqual(profile.adaptivity(for: "maths", language: "de"), Adaptivity(adjustment: 0, perfectRounds: 0))
    }

    func testGrownUpsSetOneSubjectsLevelWithoutTouchingAnythingElse() throws {
        let context = try makeContext()
        let profile = ChildProfile(name: "Emil", age: 8)
        context.insert(profile)
        ProgressRecorder(context: context).record(perfect("maths"), for: profile)
        let stars = profile.totalStars, rounds = profile.rounds.count

        ProfileMaintenance.setSubjectAdjustment(1.5, subjectID: "maths", language: "de", of: profile, in: context)
        XCTAssertEqual(profile.adaptivity(for: "maths", language: "de"), Adaptivity(adjustment: 1.5, perfectRounds: 0))
        XCTAssertEqual(profile.levelAge(for: "maths", language: "de"), 9.5)
        XCTAssertEqual(profile.subjectProgress(for: "maths", language: "de")?.roundsPlayed, 1)
        XCTAssertEqual(profile.totalStars, stars)
        XCTAssertEqual(profile.rounds.count, rounds)
        XCTAssertEqual(profile.adaptivity(for: "vocabulary", language: "de").adjustment, 0)

        // Limits: −1.5 … +3 years, in half years; a subject without progress gets an entry.
        ProfileMaintenance.setSubjectAdjustment(9, subjectID: "maths", language: "de", of: profile, in: context)
        XCTAssertEqual(profile.adaptivity(for: "maths", language: "de").adjustment, 3)
        ProfileMaintenance.setSubjectAdjustment(-0.7, subjectID: "vocabulary", language: "de", of: profile, in: context)
        XCTAssertEqual(profile.adaptivity(for: "vocabulary", language: "de").adjustment, -0.5)
    }

    func testLevelAgesAreShownInHalfYears() {
        XCTAssertEqual(ProfileEditorView.formatLevelAge(8.5), "8½")
        XCTAssertEqual(ProfileEditorView.formatLevelAge(6.45), "6½")
        XCTAssertEqual(ProfileEditorView.formatLevelAge(7.2), "7")
    }

    // MARK: Gifts and wallet

    func testGiftsAddSpendableStarsOnlyAndAreCapped() {
        let profile = ChildProfile(name: "Lena", age: 5)
        profile.totalStars = 12
        profile.walletStars = 3
        ProfileMaintenance.giveStars(50, to: profile)
        ProfileMaintenance.giveStars(25, to: profile)
        XCTAssertEqual(profile.walletStars, 78)
        XCTAssertEqual(profile.totalStars, 12, "lifetime stars stay learning stars")
        XCTAssertEqual(profile.giftStars, 75)
        ProfileMaintenance.giveStars(0, to: profile)
        XCTAssertEqual(profile.walletStars, 78)
        ProfileMaintenance.giveStars(9999, to: profile)
        XCTAssertEqual(profile.walletStars, 78 + ProfileMaintenance.giftMax)
    }

    func testOldProfilesCanSpendWhatTheyEarned() throws {
        let context = try makeContext()
        let old = ChildProfile(name: "Ida", age: 7)
        old.totalStars = 40
        old.walletReady = false   // as saved before the wallet existed
        context.insert(old)
        let fresh = ChildProfile(name: "Finn", age: 9)
        fresh.totalStars = 10
        fresh.walletStars = 2
        context.insert(fresh)

        ProfileMaintenance.prepareWallets(in: context)
        XCTAssertEqual(old.walletStars, 40)
        XCTAssertTrue(old.walletReady)
        XCTAssertEqual(fresh.walletStars, 2, "profiles with a wallet keep it")
    }

    func testResetClearsWalletGiftsAndTheWebGarden() throws {
        let context = try makeContext()
        let profile = ChildProfile(name: "Lena", age: 5)
        context.insert(profile)
        ProfileMaintenance.giveStars(20, to: profile)
        profile.backupExtras = BackupExtras.encode(["id": "abc", "garden": [["itemId": "barn"]], "farmXp": 80, "gamesEnabled": false])

        ProfileMaintenance.resetProgress(of: profile, in: context)
        XCTAssertEqual(profile.walletStars, 0)
        XCTAssertEqual(profile.giftStars, 0)
        let extras = BackupExtras.decode(profile.backupExtras)
        XCTAssertNil(extras["garden"])
        XCTAssertNil(extras["farmXp"])
        XCTAssertEqual(extras["gamesEnabled"] as? Bool, false, "settings stay")
        XCTAssertEqual(extras["id"] as? String, "abc")
    }
}
