import SwiftData
import SwiftUI
import UniformTypeIdentifiers

/// "Sicherung" in the grown-up area: saves all profiles to a file in the web
/// app's format, or restores them from one (replacing the profiles on this device).
struct BackupSection: View {
    let profiles: [ChildProfile]

    @Environment(\.modelContext) private var modelContext
    @AppStorage(AppLaunch.activeProfileKey) private var activeProfileID = ""
    @AppStorage("lastBackupAt") private var lastBackupAt: Double = 0
    @State private var document: BackupDocument?
    @State private var isExporting = false
    @State private var isImporting = false
    @State private var restoring: Backup.Contents?
    /// A catalog key: what just happened ("backup.saved", "backup.problem.notJson" …).
    @State private var note: String?

    var body: some View {
        Section {
            Button {
                saveBackup()
            } label: {
                Label("backup.save", systemImage: "square.and.arrow.down")
            }
            .disabled(profiles.isEmpty)
            .accessibilityIdentifier("backup-save")
            .fileExporter(isPresented: $isExporting, document: document, contentType: .json, defaultFilename: Self.baseName(Backup.fileName())) { result in
                if case .success = result {
                    lastBackupAt = Date.now.timeIntervalSince1970
                    note = "backup.saved"
                }
            }

            Button {
                isImporting = true
            } label: {
                Label("backup.load", systemImage: "folder")
            }
            .accessibilityIdentifier("backup-load")
            .fileImporter(isPresented: $isImporting, allowedContentTypes: [.json]) { result in
                guard case .success(let url) = result else { return }
                load(url)
            }

            if let note {
                Text(LocalizedStringKey(note))
                    .font(.funkelCaption)
                    .foregroundStyle(note.hasPrefix("backup.problem.") ? Color.orange : Palette.correct)
                    .accessibilityIdentifier("backup-note")
            }
        } header: {
            Text("backup.title")
        } footer: {
            VStack(alignment: .leading, spacing: 4) {
                if lastBackupAt > 0 {
                    let lastText = Date(timeIntervalSince1970: lastBackupAt).formatted(date: .abbreviated, time: .shortened)
                    Text("backup.last \(lastText)")
                } else {
                    Text("backup.never")
                }
                Text("backup.footer")
            }
        }
        .sheet(isPresented: Binding(get: { restoring != nil }, set: { if !$0 { restoring = nil } })) {
            if let restoring {
                RestoreConfirmation(contents: restoring, onRestore: { restore(restoring) }, onCancel: { self.restoring = nil })
            }
        }
    }

    private func saveBackup() {
        guard let data = try? Backup.export(profiles) else { return }
        document = BackupDocument(data: data)
        note = nil
        isExporting = true
    }

    private func load(_ url: URL) {
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url) else {
            note = "backup.problem.notJson"
            return
        }
        switch Backup.read(data) {
        case .success(let contents):
            note = nil
            restoring = contents
        case .failure(let problem):
            note = "backup.problem." + problem.rawValue
        }
    }

    private func restore(_ contents: Backup.Contents) {
        guard (try? Backup.restore(contents, into: modelContext)) != nil else { return }
        activeProfileID = ""
        restoring = nil
        note = "backup.restored"
    }

    /// The file exporter adds ".json" itself.
    static func baseName(_ fileName: String) -> String {
        fileName.hasSuffix(".json") ? String(fileName.dropLast(5)) : fileName
    }
}

/// "Sicherung wiederherstellen?" – what's in the file, and a clear warning.
private struct RestoreConfirmation: View {
    let contents: Backup.Contents
    let onRestore: () -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationStack {
            List {
                if let exportedAt = contents.exportedAt {
                    let dateText = exportedAt.formatted(date: .abbreviated, time: .shortened)
                    Section {
                        Text("backup.from \(dateText)")
                            .foregroundStyle(.secondary)
                    }
                }
                Section {
                    ForEach(contents.profiles) { entry in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(verbatim: entry.name).font(.funkelHeadline)
                                Text("profile.age \(entry.age)").font(.funkelCaption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Label {
                                Text(verbatim: "\(entry.totalStars)")
                            } icon: {
                                Image(systemName: "star.fill").foregroundStyle(Palette.sun)
                            }
                            .font(.funkelCaption)
                        }
                    }
                } footer: {
                    Text("backup.restoreWarning")
                }
                Section {
                    Button(role: .destructive, action: onRestore) {
                        Label("backup.restore", systemImage: "arrow.counterclockwise")
                    }
                    .accessibilityIdentifier("backup-restore")
                }
            }
            .navigationTitle("backup.restoreTitle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("editor.cancel", action: onCancel)
                }
            }
        }
    }
}

/// The backup as a file for the "save to Files" sheet.
struct BackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    var data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else { throw CocoaError(.fileReadCorruptFile) }
        self.data = data
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
