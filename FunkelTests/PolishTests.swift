import AVFoundation
import XCTest
@testable import Funkel

final class PolishTests: XCTestCase {

    // MARK: Sound

    func testEveryEffectRendersAudibleUnclippedAudio() throws {
        let format = try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate: SoundService.sampleRate, channels: 1))
        for effect in SoundService.Effect.allCases {
            let buffer = try XCTUnwrap(SoundService.render(SoundService.notes(for: effect), format: format), "\(effect)")
            let samples = UnsafeBufferPointer(start: buffer.floatChannelData![0], count: Int(buffer.frameLength))
            let peak = samples.map { abs($0) }.max() ?? 0
            XCTAssertGreaterThan(peak, 0.05, "\(effect) is silent")
            XCTAssertLessThanOrEqual(peak, 1, "\(effect) clips")
            XCTAssertLessThan(Double(buffer.frameLength) / SoundService.sampleRate, 1.2, "\(effect) is too long")
        }
    }

    func testWrongAnswerSoundIsQuieterAndLowerThanCorrect() {
        let gentle = SoundService.notes(for: .gentle)
        let correct = SoundService.notes(for: .correct)
        XCTAssertLessThan(gentle.map(\.volume).max()!, correct.map(\.volume).max()!)
        XCTAssertLessThan(gentle.map(\.frequency).max()!, correct.map(\.frequency).min()!)
    }

    // MARK: Text fitting

    func testFittingSizeShrinksForLongWordsOnly() {
        let wide = TextFitting.fittingSize(for: ["Gelb", "Blau", "Lila"], width: 120, maxSize: 34, minSize: 15, weight: .bold)
        XCTAssertEqual(wide, 34, "short words keep the full size")

        let long = TextFitting.fittingSize(for: ["Die Himmelsrichtung", "Die Uhrzeit"], width: 140, maxSize: 34, minSize: 15, weight: .bold)
        XCTAssertLessThan(long, 34)
        XCTAssertLessThanOrEqual(TextFitting.width(of: "Himmelsrichtung", size: long, weight: .bold), 140)
    }

    func testFittingSizeIsSharedByTheWholeGroup() {
        let group = ["Die Himmelsrichtung", "Die Temperatur", "Die Uhrzeit", "Die Geschwindigkeit"]
        let size = TextFitting.fittingSize(for: group, width: 150, maxSize: 24, minSize: 15, weight: .semibold)
        for text in group {
            for word in text.split(separator: " ") {
                XCTAssertLessThanOrEqual(TextFitting.width(of: String(word), size: size, weight: .semibold), 150, String(word))
            }
        }
    }

    func testFittingSizeRespectsMinimum() {
        let size = TextFitting.fittingSize(for: ["Durchhaltevermögen"], width: 20, maxSize: 34, minSize: 15, weight: .bold)
        XCTAssertEqual(size, 15)
    }

    // MARK: Read-aloud

    func testVoiceMatchesTheLearningLanguage() throws {
        let germanVoices = AVSpeechSynthesisVoice.speechVoices().filter { $0.language.hasPrefix("de") }
        try XCTSkipIf(germanVoices.isEmpty, "No German voice installed on this simulator")
        let voice = try XCTUnwrap(SpeechService.voice(for: "de-DE"))
        XCTAssertTrue(voice.language.hasPrefix("de"))
    }

    func testEveryLanguageCanReadTheAnswerAloud() throws {
        let library = ContentLibrary.bundled()
        for language in library.languages {
            let phrasing = try library.phrasing(language: language.code)
            let text = phrasing.text("speech.answer", ["answer": "42"])
            XCTAssertTrue(text.contains("42"), language.code)
            XCTAssertFalse(text.contains("{"), language.code)
        }
    }
}
