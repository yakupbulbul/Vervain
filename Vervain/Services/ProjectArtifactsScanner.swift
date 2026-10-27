import Foundation

/// Settings for the Project Artifacts module.
struct ProjectArtifactsConfig: Sendable, Equatable {
    /// A project counts as idle once nothing in it changed for this many days.
    /// Only idle projects get their artifacts pre-selected.
    var minIdleDays: Int

    static let idleKey = "projectArtifactsMinIdleDays"
    static let defaultMinIdleDays = 7

    static func fromDefaults(_ defaults: UserDefaults = .standard) -> ProjectArtifactsConfig {
        let days = defaults.object(forKey: idleKey) as? Int ?? defaultMinIdleDays
        return ProjectArtifactsConfig(minIdleDays: max(0, days))
    }
}

/// Whether git would ignore a path. Ignored folders are build output by
/// definition, so removing them cannot lose tracked work.
enum GitIgnoreState: Sendable, Equatable {
    case ignored
    case notIgnored
    /// No repository, no usable git, or git failed. Treated with caution.
    case unknown
}

enum GitIgnoreProbe {
    /// Real git binaries only. `/usr/bin/git` is a shim that pops up the
    /// Command Line Tools installer when they are missing, so it is not used.
    private static let candidates = [
        "/opt/homebrew/bin/git",
        "/usr/local/bin/git",
        "/Library/Developer/CommandLineTools/usr/bin/git",
        "/Applications/Xcode.app/Contents/Developer/usr/bin/git"
    ]

    static let gitPath: String? = candidates.first { FileManager.default.isExecutableFile(atPath: $0) }

    static func state(of url: URL) -> GitIgnoreState {
        guard let git = gitPath else { return .unknown }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: git)
        process.arguments = [
            "-C", url.deletingLastPathComponent().path,
            "check-ignore", "-q", "--", url.lastPathComponent
        ]
        process.environment = [
            "GIT_OPTIONAL_LOCKS": "0",
            "GIT_TERMINAL_PROMPT": "0",
            "HOME": NSHomeDirectory(),
            "PATH": "/usr/bin:/bin"
        ]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
        } catch {
            return .unknown
        }
        process.waitUntilExit()
        switch process.terminationStatus {
        case 0:  return .ignored
        case 1:  return .notIgnored
        default: return .unknown
        }
    }
}

/// A folder name that a build tool recreates, plus the evidence that makes the
/// name trustworthy. A bare `build` or `dist` folder is only an artifact when a
/// project file sits next to it.
struct ProjectArtifactRule: Sendable {
    let directory: String
    let label: String
    /// Any one of these files must sit next to the folder.
    let siblingMarkers: [String]
    /// Or this file must sit inside the folder (virtual environments).
    let insideMarker: String?

    init(_ directory: String, _ label: String, siblings: [String] = [], inside: String? = nil) {
        self.directory = directory
        self.label = label
        self.siblingMarkers = siblings
        self.insideMarker = inside
    }
}

/// Finds rebuildable build output and dependency folders (`node_modules`,
/// `target`, `.build`, `Pods` …) inside project folders, grouped by project.
///
/// Safety rules:
/// - a folder is only an artifact when a project file proves what it is
/// - symlinks are never followed and nested repositories are skipped
/// - only git-ignored artifacts of idle projects are pre-selected
/// - artifacts git does not ignore are `.low` confidence and never pre-selected
actor ProjectArtifactsScanner {

    static let maxDepth = 6
    static let maxCategories = 300
    static let concurrency = 6

    static let rules: [ProjectArtifactRule] = {
        let js = ["package.json"]
        let gradle = ["build.gradle", "build.gradle.kts", "settings.gradle", "settings.gradle.kts"]
        return [
            ProjectArtifactRule("node_modules", String(localized: "Node.js dependencies"), siblings: js),
            ProjectArtifactRule(".next", String(localized: "Next.js build cache"), siblings: js),
            ProjectArtifactRule(".nuxt", String(localized: "Nuxt build cache"), siblings: js),
            ProjectArtifactRule(".svelte-kit", String(localized: "SvelteKit build cache"), siblings: js),
            ProjectArtifactRule(".angular", String(localized: "Angular build cache"), siblings: js),
            ProjectArtifactRule(".turbo", String(localized: "Turborepo cache"), siblings: js),
            ProjectArtifactRule(".parcel-cache", String(localized: "Parcel cache"), siblings: js),
            ProjectArtifactRule(".expo", String(localized: "Expo cache"), siblings: js),
            ProjectArtifactRule("dist", String(localized: "Build output"), siblings: js),
            ProjectArtifactRule("build", String(localized: "Build output"),
                                siblings: js + gradle + ["CMakeLists.txt", "pom.xml"]),
            ProjectArtifactRule("target", String(localized: "Rust build output"), siblings: ["Cargo.toml"]),
            ProjectArtifactRule("target", String(localized: "Maven build output"), siblings: ["pom.xml"]),
            ProjectArtifactRule(".build", String(localized: "Swift package build output"), siblings: ["Package.swift"]),
            ProjectArtifactRule("Pods", String(localized: "CocoaPods dependencies"), siblings: ["Podfile"]),
            ProjectArtifactRule(".gradle", String(localized: "Gradle cache"), siblings: gradle),
            ProjectArtifactRule(".dart_tool", String(localized: "Dart tool cache"), siblings: ["pubspec.yaml"]),
            ProjectArtifactRule("venv", String(localized: "Python virtual environment"), inside: "pyvenv.cfg"),
            ProjectArtifactRule(".venv", String(localized: "Python virtual environment"), inside: "pyvenv.cfg")
        ]
    }()

    private static let rulesByDirectory = Dictionary(grouping: rules, by: \.directory)

    /// Folders never entered while looking for projects.
    private static let skippedNames: Set<String> = ["Library", "Applications", "node_modules"]

    /// Where developers usually keep code, plus anything added in Settings.
    static func defaultRoots(
        defaults: UserDefaults = .standard,
        home: URL = FileManager.default.homeDirectoryForCurrentUser
    ) -> [URL] {
        let names = ["Projects", "GitHub", "dev", "Developer", "Code", "src", "repos",
                     "workspace", "Sites", "Documents", "Desktop"]
        let candidates = names.map { home.appendingPathComponent($0) }
            + ScanRoots.extras(defaults).map { URL(fileURLWithPath: $0) }
        var result: [URL] = []
        for url in candidates.map({ $0.standardizedFileURL }) {
            let path = url.path
            guard FileManager.default.fileExists(atPath: path) else { continue }
            if result.contains(where: { path == $0.path || path.hasPrefix($0.path + "/") }) { continue }
            result.removeAll { $0.path.hasPrefix(path + "/") }
            result.append(url)
        }
        return result
    }

    fileprivate struct Found: Sendable {
        let project: URL
        let artifact: URL
        let rule: ProjectArtifactRule
    }

    func scan(
        config: ProjectArtifactsConfig,
        roots: [URL]? = nil,
        now: Date? = nil,
        ignoreState: (@Sendable (URL) -> GitIgnoreState)? = nil
    ) async throws -> (categories: [CleanupCategory], metadata: ScanMetadata) {
        let roots = roots ?? Self.defaultRoots()
        let now = now ?? Date()
        let ignoreState = ignoreState ?? { GitIgnoreProbe.state(of: $0) }
        let started = Date()
        var meta = ScanMetadata()

        var found: [Found] = []
        for root in roots {
            try findArtifacts(in: root, into: &found, errors: &meta.errors)
        }
        meta.inaccessibleCount = meta.errors.count

        // Sizing a big node_modules takes seconds, so artifacts are measured in
        // parallel, a few at a time.
        let projectArtifactNames = Dictionary(grouping: found, by: \.project)
            .mapValues { Set($0.map { $0.artifact.lastPathComponent }) }
        var itemsByProject: [String: (project: URL, items: [CleanupItem])] = [:]
        try await withThrowingTaskGroup(of: (URL, CleanupItem?).self) { group in
            var iterator = found.makeIterator()
            var running = 0
            func addNext() -> Bool {
                guard let hit = iterator.next() else { return false }
                let siblingNames = projectArtifactNames[hit.project] ?? []
                group.addTask {
                    (hit.project, Self.evaluate(
                        hit, siblingNames: siblingNames, config: config, now: now, ignoreState: ignoreState
                    ))
                }
                return true
            }
            while running < Self.concurrency, addNext() { running += 1 }
            while let (project, item) = try await group.next() {
                try Task.checkCancellation()
                if let item { itemsByProject[project.path, default: (project, [])].items.append(item) }
                _ = addNext()
            }
        }

        var categories = itemsByProject.values.map { entry -> CleanupCategory in
            CleanupCategory(
                kind: .projectArtifacts,
                title: entry.project.lastPathComponent,
                subtitle: CleanupItem.makeDisplayPath(url: entry.project),
                icon: "shippingbox",
                sourceModule: .projectArtifacts,
                items: entry.items.sorted { $0.size > $1.size }
            )
        }
        categories.sort { $0.totalSize > $1.totalSize }
        if categories.count > Self.maxCategories { categories = Array(categories.prefix(Self.maxCategories)) }

        meta.scannedCount = categories.reduce(0) { $0 + $1.itemCount }
        meta.duration = Date().timeIntervalSince(started)
        return (categories, meta)
    }

    // MARK: - Evaluation

    private static func evaluate(
        _ hit: Found,
        siblingNames: Set<String>,
        config: ProjectArtifactsConfig,
        now: Date,
        ignoreState: @Sendable (URL) -> GitIgnoreState
    ) -> CleanupItem? {
        let stats = directoryStats(at: hit.artifact)
        guard stats.size > 0 else { return nil }

        let activity = projectActivity(hit.project, excluding: siblingNames, artifactNewest: stats.newestModification)
        let idleDays = max(0, Int(now.timeIntervalSince(activity) / 86_400))
        let idle = idleDays >= config.minIdleDays

        let risk: CleanupRiskLevel
        let confidence: CleanupConfidenceLevel
        let reason: CleanupReason
        switch ignoreState(hit.artifact) {
        case .ignored:
            risk = idle ? .safe : .review
            confidence = idle ? .high : .medium
            reason = .projectArtifact(label: hit.rule.label, idleDays: idleDays)
        case .unknown:
            risk = .review
            confidence = .medium
            reason = .projectArtifact(label: hit.rule.label, idleDays: idleDays)
        case .notIgnored:
            risk = .review
            confidence = .low
            reason = .custom(String(localized: "\(hit.rule.label) — not in .gitignore, check that it is not part of the project"))
        }

        return CleanupItem(
            url: hit.artifact,
            size: stats.size,
            category: hit.project.lastPathComponent,
            reason: reason,
            riskLevel: risk,
            confidenceLevel: confidence,
            lastModifiedDate: activity,
            sourceModule: .projectArtifacts
        )
    }

    // MARK: - Discovery

    private func findArtifacts(in root: URL, into found: inout [Found], errors: inout [ScanError]) throws {
        let fm = FileManager.default
        let keys: [URLResourceKey] = [.isDirectoryKey, .isSymbolicLinkKey, .isPackageKey]

        func visit(_ dir: URL, depth: Int) throws {
            try Task.checkCancellation()
            let children: [URL]
            do {
                children = try fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: keys, options: [])
            } catch {
                errors.append(ScanError(path: dir.path, reason: .permissionDenied))
                return
            }
            let names = Set(children.map(\.lastPathComponent))
            var subdirectories: [URL] = []

            for child in children {
                guard let rv = try? child.resourceValues(forKeys: Set(keys)),
                      rv.isDirectory == true, rv.isSymbolicLink != true else { continue }
                let name = child.lastPathComponent

                if let rules = Self.rulesByDirectory[name],
                   let rule = rules.first(where: { matches($0, siblings: names, candidate: child) }) {
                    // A folder that is itself a repository is never build output.
                    if fm.fileExists(atPath: child.appendingPathComponent(".git").path) { continue }
                    found.append(Found(project: dir, artifact: child, rule: rule))
                    continue
                }
                if name.hasPrefix(".") || Self.skippedNames.contains(name) || rv.isPackage == true { continue }
                subdirectories.append(child)
            }

            guard depth < Self.maxDepth else { return }
            for sub in subdirectories { try visit(sub, depth: depth + 1) }
        }

        try visit(root, depth: 0)
    }

    private func matches(
        _ rule: ProjectArtifactRule,
        siblings: Set<String>,
        candidate: URL
    ) -> Bool {
        if let inside = rule.insideMarker {
            return FileManager.default.fileExists(atPath: candidate.appendingPathComponent(inside).path)
        }
        return rule.siblingMarkers.contains { siblings.contains($0) }
    }

    /// Newest sign of life in the project: its own folder, its project file and
    /// everything directly inside it (source folders, `.git`), except the
    /// artifacts being judged. Falls back on the artifact's own newest file.
    private static func projectActivity(
        _ project: URL,
        excluding artifactNames: Set<String>,
        artifactNewest: Date
    ) -> Date {
        let fm = FileManager.default
        let key: URLResourceKey = .contentModificationDateKey
        var newest = artifactNewest
        func absorb(_ url: URL) {
            if let date = try? url.resourceValues(forKeys: [key]).contentModificationDate, date > newest {
                newest = date
            }
        }
        absorb(project)
        let entries = (try? fm.contentsOfDirectory(
            at: project, includingPropertiesForKeys: [key], options: []
        )) ?? []
        for entry in entries where !artifactNames.contains(entry.lastPathComponent) {
            absorb(entry)
        }
        return newest
    }
}
