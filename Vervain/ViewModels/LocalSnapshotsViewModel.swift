import SwiftUI

@Observable
@MainActor
final class LocalSnapshotsViewModel {

    enum State: Equatable {
        case idle
        case scanning
        case results
    }

    var state: State = .idle
    var report = LocalSnapshotsReport(snapshots: [], purgeableBytes: 0, errorMessage: nil)

    private let service = LocalSnapshotsService()
    private var task: Task<Void, Never>?

    func scan() {
        task?.cancel()
        task = Task {
            state = .scanning
            let result = await service.report()
            guard !Task.isCancelled else { return }
            report = result
            state = .results
        }
    }

    func copy(_ command: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(command, forType: .string)
    }
}
