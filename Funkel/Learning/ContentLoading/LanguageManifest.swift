import Foundation

/// Raw `Content/<lang>/manifest.json`. See PLAN.md §6.1.
struct LanguageManifest: Decodable, Sendable {
    struct Subject: Decodable, Sendable {
        let id: String
        /// Kept as a string so unknown kinds from newer content are skipped, not fatal.
        let provider: String
        let file: String
        let title: String
        let icon: String?
        let color: String?
    }

    let code: String
    let name: String
    /// BCP-47 locale for the speech synthesiser, e.g. "de-DE".
    let speechLocale: String
    let subjects: [Subject]
}

/// A content language discovered on disk, with its usable subjects.
struct ContentLanguage: Identifiable, Hashable, Sendable {
    var id: String { code }
    let code: String
    /// Endonym, e.g. "Deutsch", "Français".
    let name: String
    let speechLocale: String
    let subjects: [SubjectDescriptor]

    func subject(id: String) -> SubjectDescriptor? {
        subjects.first { $0.id == id }
    }
}
