import Foundation

/// Fields the web app keeps on a profile (play corner, Pips Garten, Sudoku …)
/// are stored here under the web app's own names and JSON shapes
/// (web/src/domain/profile.ts), inside `backupExtras`. That way backups stay
/// exchangeable with the web app without a translation step, and new features
/// need no change to the SwiftData schema.
///
///     let wallet: Int = profile.webField("gamesToday") ?? 0
///     profile.setWebField("gamesToday", wallet + 1)
extension ChildProfile {
    func webField<T: Decodable>(_ key: String, as type: T.Type = T.self) -> T? {
        guard let value = BackupExtras.decode(backupExtras)[key], !(value is NSNull),
              JSONSerialization.isValidJSONObject([value]),
              let data = try? JSONSerialization.data(withJSONObject: [value]),
              let decoded = try? JSONDecoder().decode([T].self, from: data)
        else { return nil }
        return decoded.first
    }

    /// Stores a value (nil removes the field). Remember to save the model context.
    func setWebField<T: Encodable>(_ key: String, _ value: T?) {
        var fields = BackupExtras.decode(backupExtras)
        if let value,
           let data = try? JSONEncoder().encode([value]),
           let array = try? JSONSerialization.jsonObject(with: data) as? [Any],
           let first = array.first {
            fields[key] = first
        } else {
            fields.removeValue(forKey: key)
        }
        backupExtras = BackupExtras.encode(fields)
    }
}
