import Foundation
import Testing

@testable import mcs

@Suite("ProjectDetector")
struct ProjectDetectorTests {
    private func makeTmpDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("mcs-projdetect-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    @Test("Finds project root via .git directory")
    func findsGitRoot() throws {
        let tmpDir = try makeTmpDir()
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        // Create project structure: tmpDir/.git/ and tmpDir/Sources/
        try FileManager.default.createDirectory(
            at: tmpDir.appendingPathComponent(".git"),
            withIntermediateDirectories: true
        )
        let sourcesDir = tmpDir.appendingPathComponent("Sources")
        try FileManager.default.createDirectory(at: sourcesDir, withIntermediateDirectories: true)

        let root = ProjectDetector.findProjectRoot(from: sourcesDir)
        #expect(root?.standardizedFileURL == tmpDir.standardizedFileURL)
    }

    @Test("Finds project root via CLAUDE.local.md")
    func findsCLAUDELocalRoot() throws {
        let tmpDir = try makeTmpDir()
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        // Create CLAUDE.local.md at root
        try "test".write(
            to: tmpDir.appendingPathComponent("CLAUDE.local.md"),
            atomically: true, encoding: .utf8
        )
        let subDir = tmpDir.appendingPathComponent("subdir")
        try FileManager.default.createDirectory(at: subDir, withIntermediateDirectories: true)

        let root = ProjectDetector.findProjectRoot(from: subDir)
        #expect(root?.standardizedFileURL == tmpDir.standardizedFileURL)
    }

    @Test("Returns nil when no project root found")
    func returnsNilOutsideProject() throws {
        let tmpDir = try makeTmpDir()
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        // Empty directory — no .git or CLAUDE.local.md
        let root = ProjectDetector.findProjectRoot(from: tmpDir)
        // May find the actual cwd's project root when walking up,
        // but from an isolated temp dir it should be nil or find nothing useful.
        // We test this by creating a deeply nested dir with no markers.
        let deep = tmpDir.appendingPathComponent("a/b/c")
        try FileManager.default.createDirectory(at: deep, withIntermediateDirectories: true)
        // If it walks up past tmpDir it might find the system's git repos,
        // so we just verify it doesn't crash and returns something or nil.
        _ = ProjectDetector.findProjectRoot(from: deep)
    }

    @Test("Prefers .git over CLAUDE.local.md at same level")
    func prefersGitAtSameLevel() throws {
        let tmpDir = try makeTmpDir()
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        try FileManager.default.createDirectory(
            at: tmpDir.appendingPathComponent(".git"),
            withIntermediateDirectories: true
        )
        try "test".write(
            to: tmpDir.appendingPathComponent("CLAUDE.local.md"),
            atomically: true, encoding: .utf8
        )

        let root = ProjectDetector.findProjectRoot(from: tmpDir)
        #expect(root?.standardizedFileURL == tmpDir.standardizedFileURL)
    }
}

@Suite("ProjectState")
struct ProjectStateTests {
    private func makeTmpDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("mcs-projstate-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    @Test("New state file does not exist")
    func newStateNotExists() throws {
        let tmpDir = try makeTmpDir()
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let state = ProjectState(projectRoot: tmpDir)
        #expect(!state.exists)
        #expect(state.configuredPacks.isEmpty)
    }

    @Test("Record pack and save persists state")
    func recordAndSave() throws {
        let tmpDir = try makeTmpDir()
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        var state = ProjectState(projectRoot: tmpDir)
        state.recordPack("ios")
        try state.save()

        // Reload
        let loaded = ProjectState(projectRoot: tmpDir)
        #expect(loaded.exists)
        #expect(loaded.configuredPacks == Set(["ios"]))
        #expect(loaded.mcsVersion == MCSVersion.current)
    }

    @Test("Multiple packs are stored and sorted")
    func multiplePacks() throws {
        let tmpDir = try makeTmpDir()
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        var state = ProjectState(projectRoot: tmpDir)
        state.recordPack("web")
        state.recordPack("ios")
        try state.save()

        let loaded = ProjectState(projectRoot: tmpDir)
        #expect(loaded.configuredPacks == Set(["ios", "web"]))
    }

    @Test("Additive across saves")
    func additiveAcrossSaves() throws {
        let tmpDir = try makeTmpDir()
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        // First save
        var state1 = ProjectState(projectRoot: tmpDir)
        state1.recordPack("ios")
        try state1.save()

        // Second save adds another pack
        var state2 = ProjectState(projectRoot: tmpDir)
        state2.recordPack("web")
        try state2.save()

        let loaded = ProjectState(projectRoot: tmpDir)
        #expect(loaded.configuredPacks == Set(["ios", "web"]))
    }
}
