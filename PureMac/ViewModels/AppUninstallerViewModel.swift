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

    func scan() {
        Task {
            state = .scanning
            errorMessage = nil
            do {
                apps = try await scanner.scanInstalledApps()
                state = .results
            } catch {
                errorMessage = error.localizedDescription
                state = .idle
            }
        }
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
                    return "Bundle + \(app.leftoverItems.count) leftover item\(app.leftoverItems.count == 1 ? "" : "s")"
                } else {
                    return "Bundle only — leftovers not scanned"
                }
            }()

            cats.append(CleanupCategory(
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
