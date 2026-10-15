import XCTest
@testable import Funkel

/// Runs against the real bundled `Content/` folder of the host app.
final class ContentLibraryTests: XCTestCase {
    private let library = ContentLibrary.bundled()

    func testGermanIsDiscoveredWithThreeSubjects() throws {
        let de = try XCTUnwrap(library.language(code: "de"))
        XCTAssertEqual(de.speechLocale, "de-DE")
        XCTAssertEqual(de.subjects.map(\.id), ["maths", "vocabulary", "generalKnowledge"])
        XCTAssertNil(de.subject(id: "grammar"), "German does not offer grammar")
    }

    func testEverySubjectFileDecodes() throws {
        for language in library.languages {
            _ = try library.phrasing(language: language.code)
            for subject in language.subjects {
                switch subject.provider {
                case .maths: _ = try library.mathsContent(for: subject)
                case .wordList: _ = try library.wordList(for: subject)
                case .questionBank: _ = try library.questionBank(for: subject)
                }
            }
        }
    }

    func testUnknownLanguageFallsBack() {
        XCTAssertEqual(library.resolvedLanguage(code: "xx")?.code, "de")
    }

    func testPhrasingFillsPlaceholders() throws {
        let phrasing = try library.phrasing(language: "de")
        XCTAssertEqual(phrasing.text("maths.equation", ["equation": "3 + 4"]), "Wie viel ist 3 + 4?")
    }

    /// The architecture promise: a language folder with an unknown provider
    /// kind loads, and the unknown subject is skipped instead of crashing.
    func testUnknownProviderIsSkipped() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let fr = root.appendingPathComponent("fr")
        try FileManager.default.createDirectory(at: fr, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let manifest = """
        { "code": "fr", "name": "Français", "speechLocale": "fr-FR", "subjects": [
          { "id": "grammar", "provider": "questionBank", "file": "grammar.json", "title": "Grammaire" },
          { "id": "future", "provider": "somethingNew", "file": "x.json", "title": "?" }
        ] }
        """
        try Data(manifest.utf8).write(to: fr.appendingPathComponent("manifest.json"))

        let lib = ContentLibrary(rootURL: root)
        let language = try XCTUnwrap(lib.language(code: "fr"))
        XCTAssertEqual(language.subjects.map(\.id), ["grammar"])
    }
}
