import Foundation

struct SyncDeltaSummary {
    let additions: [String]
    let removals: [String]
    let keeps: [String]

    init(previous: Set<String>, selected: Set<String>) {
        additions = selected.subtracting(previous).sorted()
        removals = previous.subtracting(selected).sorted()
        keeps = previous.intersection(selected).sorted()
    }

    var hasRemovals: Bool {
        !removals.isEmpty
    }

    var hasAnyChange: Bool {
        !additions.isEmpty || !removals.isEmpty
    }

    /// Accepts `ANSIStyle` (not a bare `Bool`) so tests can assert plain text
    /// via `ANSIStyle(enabled: false)` without leaking hardcoded escape codes.
    static func renderReviewBlock(_ summary: SyncDeltaSummary, style: ANSIStyle) -> String {
        var lines: [String] = []
        if !summary.additions.isEmpty {
            lines.append("  \(style.green)+ add:\(style.reset)      \(summary.additions.joined(separator: ", "))")
        }
        if !summary.removals.isEmpty {
            lines.append("  \(style.red)- remove:\(style.reset)   \(summary.removals.joined(separator: ", "))")
        }
        if !summary.keeps.isEmpty {
            lines.append("  \(style.dim)= keep:\(style.reset)     \(summary.keeps.joined(separator: ", "))")
        }
        return lines.joined(separator: "\n")
    }
}
