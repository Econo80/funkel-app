import Foundation

/// The engines the app knows how to run. Subjects are content bound to one of
/// these, declared per language in `Content/<lang>/manifest.json` (PLAN.md §6.1).
enum ProviderKind: String, Codable, CaseIterable, Sendable {
    /// Procedural maths. Infinite.
    case maths
    /// Questions generated from a word list (vocabulary).
    case wordList
    /// Authored questions in generic formats (general knowledge, grammar, …).
    case questionBank
}

/// A subject as offered by one content language.
struct SubjectDescriptor: Identifiable, Hashable, Sendable {
    /// Stable id, e.g. "maths", "vocabulary", "grammar". Used for progress keys.
    let id: String
    let languageCode: String
    let provider: ProviderKind
    /// Content file name inside `Content/<lang>/`.
    let file: String
    /// Display title in the learning language, e.g. "Mathe".
    let title: String
    /// SF Symbol name.
    let icon: String
    /// Hex colour, e.g. "#FF8A3D".
    let colorHex: String
}
