import SwiftData
import SwiftUI
import UniformTypeIdentifiers

/// What the backup buttons are doing: saving, picking a file, confirming a restore.
/// Shared by the section (the buttons) and `backupPresentations` (the file
/// dialogs and the confirmation), which sit on the whole list: modifiers on a
/// list section attach to its rows, and a sheet on a row that changes while it
/// opens is closed again at once.
@Observable
final class BackupFlow {
    var document: BackupDocument?
    var isExporting = false
    var isImporting = false
    var restoring: Backup.Contents?
    /// A catalog key: what just happened ("backup.saved", "backup.problem.notJson" …).
    var note: String?

    func save(_ profiles: [ChildProfile]) {
        guard let data = try? Backup.export(profiles) else { return }
        document = BackupDocument(data: data)
        note = nil
        isExporting = true
    }

    func load(_ url: URL) {
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url) else {
            note = "backup.problem.notJson"
            return
        }
        switch Backup.read(data) {
        case .success(let contents):
            note = nil
            // Let the file picker finish closing before the confirmation opens.
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(400))
                self.restoring = contents
            }
        case .failure(let problem):
            note = "backup.problem." + problem.rawValue
        }
    }
}

/// "Sicherung" in the grown-up area: saves all profiles to a file in the web
/// app's format, or restores them from one (replacing the profiles on this device).
struct BackupSection: View {
    let profiles: [ChildProfile]
    let flow: BackupFlow

    @AppStorage("lastBackupAt") private var lastBackupAt: Double = 0

    var body: some View {
        Section {
            Button {
                flow.save(profiles)
            } label: {
                Label("backup.save", systemImage: "square.and.arrow.down")
            }
            .disabled(profiles.isEmpty)
            .accessibilityIdentifier("backup-save")

            Button {
                flow.isImporting = true
            } label: {
                Label("backup.load", systemImage: "folder")
            }
            .accessibilityIdentifier("backup-load")

            if let note = flow.note {
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
    }

    /// The file exporter adds ".json" itself.
    static func baseName(_ fileName: String) -> String {
        fileName.hasSuffix(".json") ? String(fileName.dropLast(5)) : fileName
    }
}

extension View {
    /// The backup's file dialogs and restore confirmation; put it on the whole list.
    func backupPresentations(_ flow: BackupFlow) -> some View {
        modifier(BackupPresentations(flow: flow))
    }
}

private struct BackupPresentations: ViewModifier {
    @Bindable var flow: BackupFlow

    @Environment(\.modelContext) private var modelContext
    @AppStorage(AppLaunch.activeProfileKey) private var activeProfileID = ""
    @AppStorage("lastBackupAt") private var lastBackupAt: Double = 0

    func body(content: Content) -> some View {
        content
            .fileExporter(isPresented: $flow.isExporting, document: flow.document, contentType: .json, defaultFilename: BackupSection.baseName(Backup.fileName())) { result in
                if case .success = result {
                    lastBackupAt = Date.now.timeIntervalSince1970
                    flow.note = "backup.saved"
                }
            }
            .fileImporter(isPresented: $flow.isImporting, allowedContentTypes: [.json]) { result in
                guard case .success(let url) = result else { return }
                flow.load(url)
            }
            .sheet(item: $flow.restoring) { contents in
                RestoreConfirmation(contents: contents, onRestore: { restore(contents) }, onCancel: { flow.restoring = nil })
            }
    }

    private func restore(_ contents: Backup.Contents) {
        do {
            try Backup.restore(contents, into: modelContext)
            activeProfileID = ""
            flow.note = "backup.restored"
        } catch {
            flow.note = "backup.problem.notFunkel"
        }
        flow.restoring = nil
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
