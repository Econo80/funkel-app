import Foundation
import Observation

/// App-wide services, injected via `.environment(_:)`.
/// Swap in fakes for previews and tests.
@Observable
final class AppEnvironment {
    let content: ContentLibrary
    let speech: SpeechService
    let sound: SoundService

    init(content: ContentLibrary, speech: SpeechService = SpeechService(), sound: SoundService = SoundService()) {
        self.content = content
        self.speech = speech
        self.sound = sound
    }

    static func live() -> AppEnvironment {
        AppEnvironment(content: .bundled())
    }
}
