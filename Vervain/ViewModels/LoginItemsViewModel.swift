import SwiftUI

@Observable
@MainActor
final class LoginItemsViewModel {

    enum State: Equatable {
        case idle
        case scanning
        case results
    }

    var state: State = .idle
    var items: [LoginItem] = []
    var selectedIDs: Set<String> = []

    private let scanner = LoginItemsScanner()
    private var scanTask: Task<Void, Never>?

    func scan() {
        scanTask?.cancel()
        scanTask = Task {
            state = .scanning
            do {
                items = try await scanner.scan()
                selectedIDs = selectedIDs.intersection(Set(items.map(\.id)))
                state = .results
            } catch {
                state = .idle
            }
        }
    }

    func grouped() -> [(scope: LoginItem.Scope, items: [LoginItem])] {
        let order: [LoginItem.Scope] = [.userAgent, .systemAgent, .systemDaemon]
        return order.compactMap { scope in
            let matching = items.filter { $0.scope == scope }
            return matching.isEmpty ? nil : (scope: scope, items: matching)
        }
    }

    func toggle(_ item: LoginItem) {
        guard item.isRemovable else { return }
        if selectedIDs.contains(item.id) {
            selectedIDs.remove(item.id)
        } else {
            selectedIDs.insert(item.id)
        }
    }

    /// Selected launch agents as a review category. Removal goes through the
    /// same review → confirm → Trash flow as every other module.
    func buildCleanupCategories() -> [CleanupCategory] {
        let selected = items.filter { selectedIDs.contains($0.id) && $0.isRemovable }
        guard !selected.isEmpty else { return [] }
        let cleanupItems = selected.map { item in
            CleanupItem(
                url: item.plistURL,
                name: item.label,
                size: (try? item.plistURL.resourceValues(forKeys: [.fileSizeKey]).fileSize).flatMap { Int64($0) } ?? 0,
                category: "Launch Agents",
                reason: .custom(String(localized: "Starts \(item.program ?? item.label) automatically")),
                riskLevel: .review,
                confidenceLevel: .medium,
                sourceModule: .performance
            )
        }
        return [CleanupCategory(
            kind: .launchAgents,
            title: String(localized: "Launch Agents"),
            subtitle: String(localized: "Only the startup entry is removed, not the app itself"),
            icon: "power",
            sourceModule: .performance,
            items: cleanupItems
        )]
    }
}
