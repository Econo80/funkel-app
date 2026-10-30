import XCTest
@testable import Funkel

final class DifficultyScaleTests: XCTestCase {

    func testKeyframesInterpolateAndClamp() {
        let curve = Keyframes([(4, 0), (6, 10)])
        XCTAssertEqual(curve.value(at: 2), 0)
        XCTAssertEqual(curve.value(at: 5), 5, accuracy: 0.0001)
        XCTAssertEqual(curve.value(at: 20), 10)
    }

    func testEffectiveAgeIsClampedToSupportedRange() {
        XCTAssertEqual(DifficultyScale.effectiveAge(age: 4, adjustment: -1.5), 4)
        XCTAssertEqual(DifficultyScale.effectiveAge(age: 14, adjustment: 1.5), 14)
        XCTAssertEqual(DifficultyScale.effectiveAge(age: 7, adjustment: 5), 10, "up to 3 years above the age")
        XCTAssertEqual(DifficultyScale.effectiveAge(age: 7, adjustment: -5), 5.5, "down to 1½ years below")
    }

    func testYoungestChildrenOnlyCount() {
        let d = DifficultyScale.difficulty(forAge: 4)
        XCTAssertEqual(Set(d.maths.operationWeights.keys), [.counting, .numberRecognition])
        XCTAssertEqual(d.maths.countingMax, 5)
        XCTAssertEqual(d.answerOptionCount, 3)
        XCTAssertTrue(d.usesPictureOptions)
        XCTAssertFalse(d.allowsGentleTimer)
        XCTAssertFalse(d.maths.usesNumberPad)
    }

    func testOperationsUnlockWithAge() {
        let six = DifficultyScale.difficulty(forAge: 6).maths.operationWeights
        XCTAssertNotNil(six[.addition])
        XCTAssertNil(six[.multiplication])

        let nine = DifficultyScale.difficulty(forAge: 9).maths.operationWeights
        XCTAssertNotNil(nine[.multiplication])
        XCTAssertNotNil(nine[.division])
        XCTAssertNotNil(nine[.wordProblem])
        XCTAssertNil(nine[.counting])
    }

    func testWeightsAreNormalisedAtEveryAge() {
        for age in DifficultyTuning.ageRange {
            let maths = DifficultyScale.difficulty(forAge: age).maths.operationWeights.values.reduce(0, +)
            XCTAssertEqual(maths, 1, accuracy: 0.0001, "maths weights at age \(age)")
            let vocab = DifficultyScale.difficulty(forAge: age).vocabulary.questionTypeWeights.values.reduce(0, +)
            XCTAssertEqual(vocab, 1, accuracy: 0.0001, "vocabulary weights at age \(age)")
        }
    }

    func testRangesNeverShrinkAsChildGrows() {
        var previous = DifficultyScale.difficulty(effectiveAge: 4)
        for step in 1...100 {
            let current = DifficultyScale.difficulty(effectiveAge: 4 + Double(step) * 0.1)
            XCTAssertGreaterThanOrEqual(current.maths.addSubResultMax, previous.maths.addSubResultMax)
            XCTAssertGreaterThanOrEqual(current.vocabulary.spellingMaxLength, previous.vocabulary.spellingMaxLength)
            XCTAssertGreaterThanOrEqual(current.answerOptionCount, previous.answerOptionCount)
            previous = current
        }
    }

    func testTimerOnlyForOlderChildren() {
        XCTAssertFalse(DifficultyScale.difficulty(forAge: 8).allowsGentleTimer)
        XCTAssertTrue(DifficultyScale.difficulty(forAge: 9).allowsGentleTimer)
    }

    func testAdjustmentMovesGentlyAndIsCapped() {
        XCTAssertEqual(DifficultyScale.nextAdjustment(current: 0, correct: 10, total: 10), 0.15, accuracy: 0.0001)
        XCTAssertEqual(DifficultyScale.nextAdjustment(current: 0, correct: 7, total: 10), 0)
        XCTAssertEqual(DifficultyScale.nextAdjustment(current: 0, correct: 2, total: 10), -0.3, accuracy: 0.0001)
        XCTAssertEqual(DifficultyScale.nextAdjustment(current: 2.95, correct: 10, total: 10), 3)
        XCTAssertEqual(DifficultyScale.nextAdjustment(current: -1.4, correct: 0, total: 10), -1.5)
        XCTAssertEqual(DifficultyScale.nextAdjustment(current: 0.3, correct: 0, total: 0), 0.3)
    }

    func testContentEligibilityWindow() {
        let d = DifficultyScale.difficulty(forAge: 8)
        XCTAssertTrue(d.isEligible(minAge: 4, maxAge: nil))
        XCTAssertTrue(d.isEligible(minAge: 8, maxAge: 10))
        XCTAssertFalse(d.isEligible(minAge: 10, maxAge: nil), "too hard")
        XCTAssertFalse(d.isEligible(minAge: 4, maxAge: 6), "too babyish")
    }
}
