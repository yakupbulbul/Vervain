import Foundation

/// A way to run Vervain against a made-up Mac, for screenshots and demos.
///
/// Set `VERVAIN_DEMO_ROOT` to a folder that is laid out like a small Mac:
/// `Applications/` holds the apps App Uninstaller lists, `Library/` holds
/// their leftovers, and every other top-level folder is what Disk Analyzer
/// measures. Nothing outside that folder is read, so no real app names, file
/// names or disk figures can end up in an image.
///
/// It is read from the environment only. There is no setting for it in the
/// app, and with the variable unset nothing changes.
enum DemoMode {

    static let environmentKey = "VERVAIN_DEMO_ROOT"

    /// The demo folder, or nil when demo mode is off or the path is not a folder.
    static func root(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> URL? {
        guard let path = environment[environmentKey], !path.isEmpty else { return nil }
        let url = URL(fileURLWithPath: path).standardizedFileURL
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory),
              isDirectory.boolValue else { return nil }
        return url
    }

    /// The top-level folders Disk Analyzer measures in demo mode.
    static func diskAnalyzerRoots(in root: URL) -> [(path: String, label: String)] {
        let entries = (try? FileManager.default.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )) ?? []
        return entries
            .filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true }
            .map { (path: $0.path, label: $0.lastPathComponent) }
            .sorted { $0.label < $1.label }
    }
}
