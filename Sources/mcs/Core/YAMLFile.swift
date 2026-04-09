import Foundation
import Yams

/// Shared helpers for loading and saving YAML-backed files.
/// Each caller wraps these with its own error-handling policy (swallow vs throw).
enum YAMLFile {
    /// Load and decode a YAML file. Returns `nil` if the file doesn't exist or is empty.
    /// Throws on read or decode errors so callers can decide how to handle them.
    static func load<T: Decodable>(_ type: T.Type, from path: URL) throws -> T? {
        let fm = FileManager.default
        guard fm.fileExists(atPath: path.path) else { return nil }
        let content = try String(contentsOf: path, encoding: .utf8)
        if content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return nil
        }
        return try YAMLDecoder().decode(type, from: content)
    }

    /// Encode and save a value as YAML, creating parent directories if needed.
    static func save(_ value: some Encodable, to path: URL) throws {
        let fm = FileManager.default
        let dir = path.deletingLastPathComponent()
        if !fm.fileExists(atPath: dir.path) {
            try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        let yaml = try YAMLEncoder().encode(value)
        try yaml.write(to: path, atomically: true, encoding: .utf8)
    }
}
