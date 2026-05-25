import SwiftUI

@Observable
@MainActor
final class AppUninstallerViewModel {

    enum State {
        case idle, scanning, results, uninstalling, done
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
    var isUninstalling: Bool {
        if case .uninstalling = state { return true }
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

    func uninstall() {
        Task {
            state = .uninstalling
            for app in selectedApps {
                try? await scanner.uninstall(app)
                apps.removeAll { $0.id == app.id }
            }
            selectedIDs.removeAll()
            state = .done
        }
    }

    func reset() {
        apps.removeAll()
        selectedIDs.removeAll()
        state = .idle
    }
}
