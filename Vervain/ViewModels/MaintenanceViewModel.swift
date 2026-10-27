import SwiftUI

@Observable
@MainActor
final class MaintenanceViewModel {

    enum TaskState: Equatable {
        case running
        case done
        case failed(String)
    }

    private(set) var states: [MaintenanceTaskID: TaskState] = [:]
    var copiedCommand: String?

    private let runner = MaintenanceRunner()

    func run(_ id: MaintenanceTaskID) {
        guard states[id] != .running else { return }
        states[id] = .running
        Task {
            switch await runner.run(id) {
            case .succeeded:        states[id] = .done
            case .failed(let why):  states[id] = .failed(why)
            }
        }
    }

    func copy(_ command: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(command, forType: .string)
        copiedCommand = command
    }
}
