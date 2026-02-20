import Foundation

/// Tracks which settings keys were written by mcs and at what version.
///
/// Stored as a line-based sidecar file at `~/.claude/.mcs-settings-keys`.
/// Format:
/// ```
/// # version=2.0.0
/// env.CLAUDE_CODE_DISABLE_AUTO_MEMORY=2.0.0
/// permissions.defaultMode=2.0.0
/// alwaysThinkingEnabled=2.0.0
/// ```
///
/// This enables version-aware settings management:
/// - **Remove**: if a key is in the sidecar but not in the new template, mcs owns it and can remove it.
/// - **Update**: if a key's value changed, mcs can update it (it owns the key).
/// - **Preserve**: if a key is NOT in the sidecar, the user added it — mcs never touches it.
struct SettingsOwnership: Sendable {
    private let path: URL
    private(set) var entries: [String: String] // keyPath -> version

    init(path: URL) {
        self.path = path
        self.entries = [:]
        load()
    }

    // MARK: - Public API

    /// Record that mcs manages a settings key at the given version.
    mutating func record(keyPath: String, version: String) {
        entries[keyPath] = version
    }

    /// Remove ownership of a key (when mcs no longer manages it).
    mutating func remove(keyPath: String) {
        entries.removeValue(forKey: keyPath)
    }

    /// Check if mcs owns a specific settings key.
    func owns(keyPath: String) -> Bool {
        entries[keyPath] != nil
    }

    /// The version at which a key was last written by mcs.
    func version(for keyPath: String) -> String? {
        entries[keyPath]
    }

    /// All managed key paths.
    var managedKeys: [String] {
        Array(entries.keys).sorted()
    }

    /// Build ownership entries from a Settings template.
    /// Produces key paths like `env.KEY`, `permissions.defaultMode`, `alwaysThinkingEnabled`.
    static func keyPaths(from settings: Settings) -> [String] {
        var paths: [String] = []

        if let env = settings.env {
            for key in env.keys.sorted() {
                paths.append("env.\(key)")
            }
        }

        if let perms = settings.permissions {
            if perms.defaultMode != nil {
                paths.append("permissions.defaultMode")
            }
        }

        if let hooks = settings.hooks {
            for event in hooks.keys.sorted() {
                paths.append("hooks.\(event)")
            }
        }

        if let plugins = settings.enabledPlugins {
            for plugin in plugins.keys.sorted() {
                paths.append("enabledPlugins.\(plugin)")
            }
        }

        if settings.alwaysThinkingEnabled != nil {
            paths.append("alwaysThinkingEnabled")
        }

        return paths
    }

    /// Record all key paths from a Settings template at the given version.
    mutating func recordAll(from settings: Settings, version: String) {
        for keyPath in Self.keyPaths(from: settings) {
            record(keyPath: keyPath, version: version)
        }
    }

    /// Find keys that mcs previously owned but are no longer in the current template.
    /// These are candidates for removal from the user's settings.
    func staleKeys(comparedTo currentTemplate: Settings) -> [String] {
        let currentPaths = Set(Self.keyPaths(from: currentTemplate))
        return managedKeys.filter { !currentPaths.contains($0) }
    }

    // MARK: - File I/O

    func save() throws {
        let fm = FileManager.default
        let dir = path.deletingLastPathComponent()
        if !fm.fileExists(atPath: dir.path) {
            try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }

        var lines: [String] = []
        lines.append("# mcs settings ownership — do not edit manually")
        lines.append("# version=\(MCSVersion.current)")
        for (keyPath, version) in entries.sorted(by: { $0.key < $1.key }) {
            lines.append("\(keyPath)=\(version)")
        }
        let content = lines.joined(separator: "\n") + "\n"
        try content.write(to: path, atomically: true, encoding: .utf8)
    }

    private mutating func load() {
        guard let content = try? String(contentsOf: path, encoding: .utf8) else { return }
        for line in content.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty, !trimmed.hasPrefix("#") else { continue }
            guard let eqIndex = trimmed.firstIndex(of: "=") else { continue }
            let key = String(trimmed[trimmed.startIndex..<eqIndex])
            let value = String(trimmed[trimmed.index(after: eqIndex)...])
            entries[key] = value
        }
    }
}
