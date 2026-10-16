import AVFoundation

/// Read-aloud via the on-device speech synthesiser, in the learning
/// language's voice (PLAN.md §6). Works offline.
final class SpeechService {
    private let synthesizer = AVSpeechSynthesizer()

    func speak(_ text: String, locale: String) {
        synthesizer.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = Self.voice(for: locale)
        // A little slower than default, for young listeners.
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.9
        synthesizer.speak(utterance)
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
    }

    /// Exact locale ("de-DE"), then any voice for the language ("de"), then the default.
    static func voice(for locale: String) -> AVSpeechSynthesisVoice? {
        if let exact = AVSpeechSynthesisVoice(language: locale) { return exact }
        let language = String(locale.prefix { $0 != "-" && $0 != "_" })
        return AVSpeechSynthesisVoice.speechVoices().first { $0.language.hasPrefix(language) }
    }
}
