import Foundation

/// Resolves which scopes `mcs update` should refresh.
///
/// Reads `~/.mcs/projects.yaml` and the per-scope state files to enumerate every
/// place that has configured packs. Returns one entry per scope to refresh, with
/// the strategy already constructed and the pack IDs ready to re-apply.
struct UpdateScopeResolver {
    let environment: Environment
    let output: CLIOutput

    struct ScopeRun {
        let label: String
        let strategy: any SyncStrategy
        let configuredPackIDs: Set<String>
        let excludedComponents: [String: Set<String>]
        let isGlobal: Bool
        /// The project root path. `nil` for the global scope.
        let projectPath: URL?
    }

    enum Filter {
        case all
        case globalOnly
        case projectOnly
        case everywhere
    }

    func resolve(filter: Filter, projectRoot: URL?, dryRun: Bool = false) throws -> [ScopeRun] {
        let indexFile = ProjectIndex(path: environment.projectsIndexFile)
        var indexData = try indexFile.load()

        let pruned = indexFile.pruneStale(in: &indexData)
        if !pruned.isEmpty {
            output.dimmed("Pruned \(pruned.count) stale project entries from index.")
            if !dryRun {
                try indexFile.save(indexData)
            }
        }

        var runs: [ScopeRun] = []

        if filter != .projectOnly,
           let run = try buildRun(
               indexEntryPath: ProjectIndex.globalSentinel,
               in: indexData,
               strategy: GlobalSyncStrategy(environment: environment),
               label: "Global (\(environment.claudeDirectory.path))",
               isGlobal: true,
               projectPath: nil
           ) {
            runs.append(run)
        }

        switch filter {
        case .everywhere:
            for entry in indexData.projects {
                guard let projectURL = entry.url?.standardizedFileURL else { continue }
                if let run = try buildRun(
                    indexEntryPath: entry.path,
                    in: indexData,
                    strategy: ProjectSyncStrategy(projectPath: projectURL, environment: environment),
                    label: "Project: \(entry.path)",
                    isGlobal: false,
                    projectPath: projectURL
                ) {
                    runs.append(run)
                }
            }
        case .all, .projectOnly:
            if let projectRoot,
               let run = try buildRun(
                   indexEntryPath: projectRoot.standardizedFileURL.path,
                   in: indexData,
                   strategy: ProjectSyncStrategy(projectPath: projectRoot, environment: environment),
                   label: "Project (\(projectRoot.lastPathComponent))",
                   isGlobal: false,
                   projectPath: projectRoot
               ) {
                runs.append(run)
            }
        case .globalOnly:
            break
        }

        return runs
    }

    private func buildRun(
        indexEntryPath: String,
        in indexData: ProjectIndex.IndexData,
        strategy: any SyncStrategy,
        label: String,
        isGlobal: Bool,
        projectPath: URL?
    ) throws -> ScopeRun? {
        let entry = indexData.projects.first { $0.path == indexEntryPath }
        guard let entry, !entry.packs.isEmpty else { return nil }

        let state = try ProjectState(stateFile: strategy.scope.stateFile)
        let configured = state.configuredPacks
        guard !configured.isEmpty else { return nil }

        return ScopeRun(
            label: label,
            strategy: strategy,
            configuredPackIDs: configured,
            excludedComponents: state.allExcludedComponents,
            isGlobal: isGlobal,
            projectPath: projectPath
        )
    }
}
