import CryptoKit
import Foundation

/// Deterministic SHA-256 hashing of pack-contributed settings values.
enum SettingsHasher {
    /// Hash the values at the given dot-notation key paths in a JSON dictionary.
    ///
    /// Canonical form: sorted key paths, each serialized as `key=<json_value>\n`
    /// with `.sortedKeys` on values. Returns `nil` if `keyPaths` is empty.
    static func hash(keyPaths: [String], in json: [String: Any]) -> String? {
        guard !keyPaths.isEmpty else { return nil }

        var canonical = ""
        for keyPath in keyPaths.sorted() {
            let value = extractValue(keyPath, from: json)
            let jsonString: String = if let value {
                if let data = try? JSONSerialization.data(
                    withJSONObject: value, options: [.sortedKeys, .fragmentsAllowed]
                ), let str = String(data: data, encoding: .utf8) {
                    str
                } else {
                    "\(value)"
                }
            } else {
                "null"
            }
            canonical += "\(keyPath)=\(jsonString)\n"
        }

        let data = Data(canonical.utf8)
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    /// Extract a value from a JSON dictionary using dot-notation key path (one level of nesting).
    static func extractValue(_ keyPath: String, from json: [String: Any]) -> Any? {
        let parts = keyPath.split(separator: ".", maxSplits: 1)
        let topLevel = String(parts[0])
        if parts.count == 2 {
            let subKey = String(parts[1])
            guard let nested = json[topLevel] as? [String: Any] else { return nil }
            return nested[subKey]
        }
        return json[topLevel]
    }
}
