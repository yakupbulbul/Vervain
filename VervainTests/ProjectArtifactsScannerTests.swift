import XCTest
@testable import Vervain

final class ProjectArtifactsScannerTests: XCTestCase {

    private var root: URL!
    private let now = Date()

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("vervain-artifacts-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    @discardableResult
    private func makeProject(
        _ name: String,
        marker: String,
        artifact: String,
        daysOld: Int = 60,
        bytes: Int = 10_000
    ) throws -> URL {
        let fm = FileManager.default
        let project = root.appendingPathComponent(name)
        let artifactURL = project.appendingPathComponent(artifact)
        try fm.createDirectory(at: artifactURL, withIntermediateDirectories: true)
        try Data("{}".utf8).write(to: project.appendingPathComponent(marker))
        try Data(count: bytes).write(to: artifactURL.appendingPathComponent("blob.bin"))
        let date = now.addingTimeInterval(-Double(daysOld) * 86_400)
        for url in [artifactURL.appendingPathComponent("blob.bin"), artifactURL,
                    project.appendingPathComponent(marker), project] {
            try fm.setAttributes([.modificationDate: date], ofItemAtPath: url.path)
        }
        return artifactURL
    }

    private func scan(
        idleDays: Int = 7,
        state: GitIgnoreState = .ignored,
        gitActivity: @escaping @Sendable (URL, Set<String>, Date) -> Date? = { _, _, _ in nil }
    ) async throws -> [CleanupCategory] {
        try await ProjectArtifactsScanner().scan(
            config: ProjectArtifactsConfig(minIdleDays: idleDays),
            roots: [root],
            now: now,
            ignoreState: { _ in state },
            gitActivity: gitActivity
        ).categories
    }

    func testFindsNodeModulesNextToPackageJson() async throws {
        try makeProject("web", marker: "package.json", artifact: "node_modules")
        let cats = try await scan()
        XCTAssertEqual(cats.count, 1)
        XCTAssertEqual(cats[0].title, "web")
        XCTAssertEqual(cats[0].items.first?.url.lastPathComponent, "node_modules")
        XCTAssertEqual(cats[0].sourceModule, .projectArtifacts)
    }

    func testBareBuildFolderWithoutProjectFileIsIgnored() async throws {
        try makeProject("notes", marker: "README.md", artifact: "build")
        try makeProject("site", marker: "README.md", artifact: "dist")
        let cats = try await scan()
        XCTAssertTrue(cats.isEmpty)
    }

    func testTargetNeedsCargoOrMaven() async throws {
        try makeProject("rust", marker: "Cargo.toml", artifact: "target")
        try makeProject("other", marker: "Makefile", artifact: "target")
        let cats = try await scan()
        XCTAssertEqual(cats.map(\.title), ["rust"])
    }

    func testVirtualEnvIsRecognisedByPyvenvCfg() async throws {
        let venv = try makeProject("py", marker: "requirements.txt", artifact: ".venv")
        try Data("home = /usr/bin".utf8).write(to: venv.appendingPathComponent("pyvenv.cfg"))
        let fake = try makeProject("plain", marker: "requirements.txt", artifact: "venv")
        _ = fake
        let cats = try await scan()
        XCTAssertEqual(cats.map(\.title), ["py"])
    }

    func testIgnoredIdleArtifactIsSafeAndPreSelected() async throws {
        try makeProject("web", marker: "package.json", artifact: "node_modules", daysOld: 60)
        let item = try await scan().first!.items.first!
        XCTAssertEqual(item.riskLevel, .safe)
        XCTAssertEqual(item.confidenceLevel, .high)
        XCTAssertTrue(item.isSelected)
    }

    func testRecentlyTouchedProjectIsNotPreSelected() async throws {
        try makeProject("web", marker: "package.json", artifact: "node_modules", daysOld: 1)
        let item = try await scan().first!.items.first!
        XCTAssertEqual(item.riskLevel, .review)
        XCTAssertFalse(item.isSelected)
    }

    func testRecentActivityInSourceFolderKeepsProjectActive() async throws {
        let artifact = try makeProject("web", marker: "package.json", artifact: "node_modules", daysOld: 60)
        let project = artifact.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: project.appendingPathComponent("src"),
                                                withIntermediateDirectories: true)
        let item = try await scan().first!.items.first!
        XCTAssertFalse(item.isSelected)
    }

    func testArtifactGitDoesNotIgnoreIsLowConfidenceAndNeverSelected() async throws {
        try makeProject("web", marker: "package.json", artifact: "dist")
        let item = try await scan(state: .notIgnored).first!.items.first!
        XCTAssertEqual(item.confidenceLevel, .low)
        XCTAssertFalse(item.isSelected)
    }

    func testUnknownGitStateIsNeverPreSelected() async throws {
        try makeProject("web", marker: "package.json", artifact: "node_modules")
        let item = try await scan(state: .unknown).first!.items.first!
        XCTAssertFalse(item.isSelected)
    }

    func testNestedRepositoryIsSkipped() async throws {
        let artifact = try makeProject("web", marker: "package.json", artifact: "node_modules")
        try FileManager.default.createDirectory(at: artifact.appendingPathComponent(".git"),
                                                withIntermediateDirectories: true)
        let cats = try await scan()
        XCTAssertTrue(cats.isEmpty)
    }

    func testSymlinkedArtifactIsNotFollowed() async throws {
        let project = root.appendingPathComponent("web")
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)
        try Data("{}".utf8).write(to: project.appendingPathComponent("package.json"))
        let target = root.appendingPathComponent("elsewhere")
        try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)
        try Data(count: 1000).write(to: target.appendingPathComponent("x.bin"))
        try FileManager.default.createSymbolicLink(
            at: project.appendingPathComponent("node_modules"), withDestinationURL: target)
        let cats = try await scan()
        XCTAssertTrue(cats.isEmpty)
    }

    func testDoesNotDescendIntoFoundArtifacts() async throws {
        let artifact = try makeProject("web", marker: "package.json", artifact: "node_modules")
        let inner = artifact.appendingPathComponent("pkg")
        try FileManager.default.createDirectory(at: inner.appendingPathComponent("node_modules"),
                                                withIntermediateDirectories: true)
        try Data("{}".utf8).write(to: inner.appendingPathComponent("package.json"))
        try Data(count: 500).write(to: inner.appendingPathComponent("node_modules/a.bin"))
        let cats = try await scan()
        XCTAssertEqual(cats.count, 1)
        XCTAssertEqual(cats[0].items.count, 1)
    }

    func testCategoriesSortedBySizeDescending() async throws {
        try makeProject("small", marker: "package.json", artifact: "node_modules", bytes: 10_000)
        try makeProject("big", marker: "package.json", artifact: "node_modules", bytes: 500_000)
        let cats = try await scan()
        XCTAssertEqual(cats.map(\.title), ["big", "small"])
    }

    func testRealGitIgnoreDetection() async throws {
        try XCTSkipUnless(GitIgnoreProbe.gitPath != nil, "git not installed")
        let artifact = try makeProject("web", marker: "package.json", artifact: "node_modules")
        let project = artifact.deletingLastPathComponent()

        XCTAssertEqual(GitIgnoreProbe.state(of: artifact), .unknown, "no repository yet")

        let git = Process()
        git.executableURL = URL(fileURLWithPath: GitIgnoreProbe.gitPath!)
        git.arguments = ["-C", project.path, "init", "-q"]
        git.standardOutput = FileHandle.nullDevice
        git.standardError = FileHandle.nullDevice
        try git.run(); git.waitUntilExit()

        XCTAssertEqual(GitIgnoreProbe.state(of: artifact), .notIgnored)
        try Data("node_modules/\n".utf8).write(to: project.appendingPathComponent(".gitignore"))
        XCTAssertEqual(GitIgnoreProbe.state(of: artifact), .ignored)
    }

    func testRecentCommitKeepsAnOtherwiseIdleProjectActive() async throws {
        try makeProject("web", marker: "package.json", artifact: "node_modules", daysOld: 60)
        let yesterday = now.addingTimeInterval(-86_400)
        let item = try await scan(gitActivity: { _, _, _ in yesterday }).first!.items.first!
        XCTAssertFalse(item.isSelected)
        XCTAssertEqual(item.riskLevel, .review)
    }

    func testOldGitActivityDoesNotMakeAProjectLookIdleSooner() async throws {
        try makeProject("web", marker: "package.json", artifact: "node_modules", daysOld: 1)
        let longAgo = now.addingTimeInterval(-200 * 86_400)
        let item = try await scan(gitActivity: { _, _, _ in longAgo }).first!.items.first!
        XCTAssertFalse(item.isSelected, "git can only add activity, never remove it")
    }

    func testIdleProjectWithOldGitActivityIsStillPreSelected() async throws {
        try makeProject("web", marker: "package.json", artifact: "node_modules", daysOld: 60)
        let longAgo = now.addingTimeInterval(-90 * 86_400)
        let item = try await scan(gitActivity: { _, _, _ in longAgo }).first!.items.first!
        XCTAssertTrue(item.isSelected)
    }

    func testGitIsNotAskedAboutProjectsThatAlreadyLookActive() async throws {
        try makeProject("web", marker: "package.json", artifact: "node_modules", daysOld: 1)
        let calls = CallCounter()
        _ = try await scan(gitActivity: { _, _, _ in calls.increment(); return nil })
        XCTAssertEqual(calls.value, 0)
    }

    func testGitIsAskedAboutIdleLookingProjects() async throws {
        try makeProject("web", marker: "package.json", artifact: "node_modules", daysOld: 60)
        let calls = CallCounter()
        _ = try await scan(gitActivity: { _, _, _ in calls.increment(); return nil })
        XCTAssertEqual(calls.value, 1)
    }

    func testGitActivityFindsUncommittedFilesButNotArtifactContents() throws {
        try XCTSkipUnless(GitIgnoreProbe.gitPath != nil, "git not installed")
        let artifact = try makeProject("web", marker: "package.json", artifact: "node_modules")
        let project = artifact.deletingLastPathComponent()

        XCTAssertNil(GitActivityProbe.lastActivity(in: project, ignoring: ["node_modules"]),
                     "no repository yet")

        let git = Process()
        git.executableURL = URL(fileURLWithPath: GitIgnoreProbe.gitPath!)
        git.arguments = ["-C", project.path, "init", "-q"]
        git.standardOutput = FileHandle.nullDevice
        git.standardError = FileHandle.nullDevice
        try git.run(); git.waitUntilExit()

        let fm = FileManager.default
        let twoDaysAgo = Date().addingTimeInterval(-2 * 86_400)
        try fm.createDirectory(at: project.appendingPathComponent("src"), withIntermediateDirectories: true)
        let edited = project.appendingPathComponent("src/new.swift")
        try Data("x".utf8).write(to: edited)
        try fm.setAttributes([.modificationDate: twoDaysAgo], ofItemAtPath: edited.path)
        // A fresh file inside the artifact must not count as work on the project.
        try Data("x".utf8).write(to: artifact.appendingPathComponent("fresh.bin"))

        let found = try XCTUnwrap(GitActivityProbe.lastActivity(in: project, ignoring: ["node_modules"]))
        XCTAssertEqual(found.timeIntervalSince1970, twoDaysAgo.timeIntervalSince1970, accuracy: 120)
    }

    func testConfigClampsNegativeIdleDays() {
        let suite = UserDefaults(suiteName: "vervain-artifacts-\(UUID().uuidString)")!
        XCTAssertEqual(ProjectArtifactsConfig.fromDefaults(suite).minIdleDays, 7)
        suite.set(-3, forKey: ProjectArtifactsConfig.idleKey)
        XCTAssertEqual(ProjectArtifactsConfig.fromDefaults(suite).minIdleDays, 0)
    }
}

private final class CallCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0
    func increment() { lock.lock(); count += 1; lock.unlock() }
    var value: Int { lock.lock(); defer { lock.unlock() }; return count }
}
