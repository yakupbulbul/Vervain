import SwiftUI

@Observable
@MainActor
final class AppUninstallerViewModel {

    enum State {
        case idle, scanning, results
    }

    var state: State = .idle
    var apps: [AppInfo] = []
    var selectedIDs: Set<UUID> = []
    var scanningLeftoversID: UUID?
    var errorMessage: String?

    var isScanning: Bool {
        if case .scanning = state { return true }
        return false
    }

    var selectedApps: [AppInfo] {
        apps.filter { selectedIDs.contains($0.id) }
    }

    var totalSelectedSize: Int64 {
        selectedApps.reduce(0) { $0 + $1.totalSize }
    }

    private let scanner = AppScanner()
    private var scanTask: Task<Void, Never>?

    func scan() {
        scanTask?.cancel()
        scanTask = Task {
            state = .scanning
            errorMessage = nil
            do {
                apps = try await scanner.scanInstalledApps()
                // Selection refers to ids of the previous scan; drop what is gone.
                selectedIDs = selectedIDs.intersection(Set(apps.map(\.id)))
                state = .results
            } catch is CancellationError {
                state = apps.isEmpty ? .idle : .results
            } catch {
                errorMessage = error.localizedDescription
                state = .idle
            }
        }
    }

    func cancelScan() {
        scanTask?.cancel()
        scanTask = nil
        state = apps.isEmpty ? .idle : .results
    }

    /// Selects the app whose bundle is at `url` (drag & drop). Returns it, or
    /// nil if it is not one of the scanned apps.
    @discardableResult
    func selectApp(at url: URL) -> AppInfo? {
        let target = url.standardizedFileURL
        guard let app = apps.first(where: { $0.url.standardizedFileURL == target }) else { return nil }
        if selectedIDs.insert(app.id).inserted, !app.leftoverScanned {
            scanLeftovers(for: app)
        }
        return app
    }

    /// Selected apps that are running right now.
    func runningSelectedApps() -> [NSRunningApplication] {
        let bundleIDs = Set(selectedApps.map(\.bundleID))
        return NSWorkspace.shared.runningApplications.filter {
            guard let id = $0.bundleIdentifier else { return false }
            return bundleIDs.contains(id)
        }
    }

    func quitRunningSelectedApps() {
        runningSelectedApps().forEach { _ = $0.terminate() }
    }

    func scanLeftovers(for app: AppInfo) {
        Task {
            scanningLeftoversID = app.id
            let updated = await scanner.scanLeftovers(for: app)
            if let idx = apps.firstIndex(where: { $0.id == app.id }) {
                apps[idx] = updated
            }
            scanningLeftoversID = nil
        }
    }

    func toggleSelection(_ id: UUID) {
        if selectedIDs.contains(id) {
            selectedIDs.remove(id)
        } else {
            selectedIDs.insert(id)
            // Uninstalling without leftovers is rarely what people want, so
            // look for them as soon as an app is ticked.
            if let app = apps.first(where: { $0.id == id }), !app.leftoverScanned {
                scanLeftovers(for: app)
            }
        }
    }

    /// Build a CleanupCategory per selected app — bundle + leftovers — for
    /// the universal review flow.
    ///
    /// The `.app` bundle itself is always tagged `risky`/`high` so the user
    /// must explicitly acknowledge the uninstall in the confirmation sheet.
    func buildCleanupCategories() -> [CleanupCategory] {
        var cats: [CleanupCategory] = []
        for app in selectedApps {
            var items: [CleanupItem] = []

            // The .app bundle itself
            items.append(CleanupItem(
                url: app.url,
                name: app.name,
                size: app.bundleSize,
                category: "\(app.name) — Application",
                reason: .appBundle,
                riskLevel: .risky,
                confidenceLevel: .high,
                lastModifiedDate: app.lastModifiedDate,
                sourceModule: .appUninstaller
            ))
            // Leftover files (already CleanupItems with graded confidence)
            items.append(contentsOf: app.leftoverItems)

            let subtitle: String = {
                if app.leftoverScanned {
                    return String(localized: "Bundle + \(app.leftoverItems.count) leftover items")
                } else {
                    return String(localized: "Bundle only — leftovers not scanned")
                }
            }()

            cats.append(CleanupCategory(
                kind: .appLeftovers,
                title: app.name,
                subtitle: subtitle,
                icon: "xmark.app.fill",
                sourceModule: .appUninstaller,
                items: items
            ))
        }
        return cats
    }
}
