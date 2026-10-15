import Foundation
import Observation

/// App-wide services, injected via `.environment(_:)`.
/// Swap in fakes for previews and tests.
@Observable
final class AppEnvironment {
    let content: ContentLibrary

    init(content: ContentLibrary) {
        self.content = content
    }

    static func live() -> AppEnvironment {
        AppEnvironment(content: .bundled())
    }
}
