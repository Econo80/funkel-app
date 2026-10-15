import Foundation
import OSLog

/// Discovers content languages and loads their JSON files.
///
/// Languages are found by scanning `Content/*/manifest.json` in the bundle, so
/// adding French means adding `Content/fr/` — no code change (PLAN.md §6).
final class ContentLibrary: @unchecked Sendable {

    enum ContentError: LocalizedError {
        case unknownLanguage(String)
        case missingFile(String)
        case decoding(file: String, underlying: Error)

        var errorDescription: String? {
            switch self {
            case let .unknownLanguage(code): "No content for language '\(code)'"
            case let .missingFile(path): "Missing content file \(path)"
            case let .decoding(file, underlying): "Could not read \(file): \(underlying)"
            }
        }
    }

    static let fallbackLanguageCode = "de"

    let languages: [ContentLanguage]

    private let rootURL: URL?
    private var cache: [String: Any] = [:]
    private let lock = NSLock()
    private static let log = Logger(subsystem: "com.example.funkel", category: "content")

    init(rootURL: URL?, fileManager: FileManager = .default) {
        self.rootURL = rootURL
        self.languages = Self.discoverLanguages(in: rootURL, fileManager: fileManager)
    }

    static func bundled(_ bundle: Bundle = .main) -> ContentLibrary {
        ContentLibrary(rootURL: bundle.url(forResource: "Content", withExtension: nil))
    }

    // MARK: Languages

    func language(code: String) -> ContentLanguage? {
        languages.first { $0.code == code }
    }

    /// The requested language, or the fallback if it was removed from the bundle.
    func resolvedLanguage(code: String) -> ContentLanguage? {
        language(code: code) ?? language(code: Self.fallbackLanguageCode) ?? languages.first
    }

    // MARK: Files

    func phrasing(language code: String) throws -> Phrasing {
        try decode(Phrasing.self, file: "strings.json", language: code)
    }

    func mathsContent(for subject: SubjectDescriptor) throws -> MathsContent {
        try decode(MathsContent.self, file: subject.file, language: subject.languageCode)
    }

    func wordList(for subject: SubjectDescriptor) throws -> WordList {
        try decode(WordList.self, file: subject.file, language: subject.languageCode)
    }

    func questionBank(for subject: SubjectDescriptor) throws -> QuestionBank {
        try decode(QuestionBank.self, file: subject.file, language: subject.languageCode)
    }

    /// Decodes `Content/<language>/<file>`, caching the result.
    func decode<T: Decodable>(_ type: T.Type, file: String, language code: String) throws -> T {
        let key = "\(code)/\(file)#\(T.self)"
        lock.lock()
        defer { lock.unlock() }

        if let cached = cache[key] as? T { return cached }

        guard language(code: code) != nil, let rootURL else { throw ContentError.unknownLanguage(code) }
        let url = rootURL.appendingPathComponent(code, isDirectory: true).appendingPathComponent(file)
        guard let data = try? Data(contentsOf: url) else { throw ContentError.missingFile("\(code)/\(file)") }

        do {
            let value = try JSONDecoder().decode(T.self, from: data)
            cache[key] = value
            return value
        } catch {
            throw ContentError.decoding(file: "\(code)/\(file)", underlying: error)
        }
    }

    // MARK: Discovery

    private static func discoverLanguages(in rootURL: URL?, fileManager: FileManager) -> [ContentLanguage] {
        guard let rootURL else {
            log.error("Content folder not found in bundle")
            return []
        }
        let folders = (try? fileManager.contentsOfDirectory(
            at: rootURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )) ?? []

        return folders.compactMap { folder -> ContentLanguage? in
            let manifestURL = folder.appendingPathComponent("manifest.json")
            guard let data = try? Data(contentsOf: manifestURL) else { return nil }
            do {
                let manifest = try JSONDecoder().decode(LanguageManifest.self, from: data)
                return makeLanguage(from: manifest, folderName: folder.lastPathComponent)
            } catch {
                log.error("Invalid manifest in \(folder.lastPathComponent, privacy: .public): \(error.localizedDescription, privacy: .public)")
                return nil
            }
        }
        .sorted { $0.code < $1.code }
    }

    private static func makeLanguage(from manifest: LanguageManifest, folderName: String) -> ContentLanguage {
        if manifest.code != folderName {
            log.error("Manifest code '\(manifest.code, privacy: .public)' does not match folder '\(folderName, privacy: .public)'; using folder name")
        }
        let code = folderName
        let subjects = manifest.subjects.compactMap { raw -> SubjectDescriptor? in
            guard let kind = ProviderKind(rawValue: raw.provider) else {
                log.info("Skipping subject '\(raw.id, privacy: .public)': unknown provider '\(raw.provider, privacy: .public)'")
                return nil
            }
            return SubjectDescriptor(
                id: raw.id,
                languageCode: code,
                provider: kind,
                file: raw.file,
                title: raw.title,
                icon: raw.icon ?? "star.fill",
                colorHex: raw.color ?? "#FFB84D"
            )
        }
        return ContentLanguage(code: code, name: manifest.name, speechLocale: manifest.speechLocale, subjects: subjects)
    }
}
