import CryptoKit
import Foundation

/// The on-disk app record. Older releases wrote the same fields without a path mapping.
struct BackupManifest: Codable {
    static let filename = "app_config.json"
    let app: AppConfig
    let entries: [BackupEntry]?

    private enum CodingKeys: String, CodingKey { case backupEntries }

    init(app: AppConfig, savedEntries: [BackupEntry]) {
        var savedApp = app
        savedApp.configPaths = savedEntries.map(\.originalPath)
        self.app = savedApp
        entries = savedEntries
    }

    init(from decoder: Decoder) throws {
        app = try AppConfig(from: decoder)
        let fields = try decoder.container(keyedBy: CodingKeys.self)
        entries = fields.contains(.backupEntries) ? try fields.decode([BackupEntry].self, forKey: .backupEntries) : nil
    }

    func encode(to encoder: Encoder) throws {
        try app.encode(to: encoder)
        var fields = encoder.container(keyedBy: CodingKeys.self)
        try fields.encodeIfPresent(entries, forKey: .backupEntries)
    }

    /// Preserve ordinary bundle IDs while distinguishing case even on a case-insensitive volume.
    static func directory(in root: URL, bundleID: String) -> URL {
        let readable = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789.-")
        if let encoded = bundleID.addingPercentEncoding(withAllowedCharacters: readable), encoded.utf8.count <= 250 {
            return root.appendingPathComponent("app-" + encoded, isDirectory: true)
        }
        let digest = SHA256.hash(data: Data(bundleID.utf8)).map { String(format: "%02x", $0) }.joined()
        return root.appendingPathComponent("id-" + digest, isDirectory: true)
    }

    private static func basename(_ path: String) -> String {
        URL(fileURLWithPath: NSString(string: path).expandingTildeInPath).lastPathComponent
    }

    private static func nameKey(_ name: String) -> String {
        name.folding(options: .caseInsensitive, locale: Locale(identifier: "en_US_POSIX"))
    }

    private static func isComponent(_ name: String) -> Bool {
        !name.isEmpty && name != "." && name != ".." && !name.contains("/") && !name.utf8.contains(0)
    }

    static func entries(for paths: [String]) -> [BackupEntry] {
        let originalNames = Set(paths.map { nameKey(basename($0)) })
        var used = Set([nameKey(filename)])
        var seenPaths: Set<String> = []
        return paths.compactMap { path in
            guard seenPaths.insert(path).inserted else { return nil }
            let base = basename(path)
            var name = base
            if !isComponent(name) || used.contains(nameKey(name)) {
                var suffix = 2
                repeat {
                    name = "\(base)_\(suffix)"
                    if !isComponent(name) || name.utf8.count > 255 { name = "item_\(suffix)" }
                    suffix += 1
                } while originalNames.contains(nameKey(name)) || used.contains(nameKey(name))
            }
            used.insert(nameKey(name))
            return BackupEntry(originalPath: path, storedName: name)
        }
    }

    static func restoreEntries(paths: [String], mapping: [BackupEntry]?, in directory: String) throws -> [BackupEntry] {
        let entries = mapping ?? paths.map {
            BackupEntry(originalPath: $0, storedName: basename($0))
        }
        var used = Set([nameKey(filename)])
        let mappedPaths = Set(entries.map(\.originalPath))
        guard entries.count == mappedPaths.count, mappedPaths == Set(paths) else {
            throw AppError.invalidBackupFormat(path: directory)
        }
        for entry in entries {
            guard isComponent(entry.storedName), used.insert(nameKey(entry.storedName)).inserted else {
                throw AppError.invalidBackupFormat(path: entry.originalPath)
            }
        }
        return entries
    }
}
