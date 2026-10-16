import Foundation
import Observation

/// App-wide services, injected via `.environment(_:)`.
/// Swap in fakes for previews and tests.
@Observable
final class AppEnvironment {
    let content: ContentLibrary
    let speech: SpeechService

    init(content: ContentLibrary, speech: SpeechService = SpeechService()) {
        self.content = content
        self.speech = speech
    }

    static func live() -> AppEnvironment {
        AppEnvironment(content: .bundled())
    }
}
