import Foundation

/// Lists launchd agents and daemons that start automatically. Apple's own
/// (`com.apple.*`) are left out. The scan only reads property lists.
actor LoginItemsScanner {

    func scan(
        home: URL = FileManager.default.homeDirectoryForCurrentUser,
        systemRoot: URL = URL(fileURLWithPath: "/")
    ) async throws -> [LoginItem] {
        let locations: [(URL, LoginItem.Scope)] = [
            (home.appendingPathComponent("Library/LaunchAgents"), .userAgent),
            (systemRoot.appendingPathComponent("Library/LaunchAgents"), .systemAgent),
            (systemRoot.appendingPathComponent("Library/LaunchDaemons"), .systemDaemon),
        ]

        var items: [LoginItem] = []
        for (folder, scope) in locations {
            try Task.checkCancellation()
            let names = (try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []
            for name in names.sorted() where name.hasSuffix(".plist") {
                let url = folder.appendingPathComponent(name)
                guard let item = Self.parse(plistAt: url, scope: scope) else { continue }
                if item.label.hasPrefix("com.apple.") { continue }
                items.append(item)
            }
        }
        return items
    }

    /// Reads one launchd property list. Returns nil if it is not a valid job.
    static func parse(plistAt url: URL, scope: LoginItem.Scope) -> LoginItem? {
        guard let data = try? Data(contentsOf: url),
              let object = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil),
              let dict = object as? [String: Any] else { return nil }

        let label = dict["Label"] as? String ?? url.deletingPathExtension().lastPathComponent
        let program = (dict["Program"] as? String)
            ?? (dict["ProgramArguments"] as? [String])?.first
        return LoginItem(
            id: url.path,
            label: label,
            program: program,
            plistURL: url,
            scope: scope,
            runsAtLoad: dict["RunAtLoad"] as? Bool ?? false,
            isDisabled: dict["Disabled"] as? Bool ?? false
        )
    }
}
