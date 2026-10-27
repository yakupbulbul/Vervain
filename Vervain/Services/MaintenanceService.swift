import Foundation

enum MaintenanceTaskID: String, CaseIterable, Sendable {
    case resetQuickLook, restartFinder, restartDock, restartMenuBar
    case flushDNS, reindexSpotlight, purgeMemory
}

/// A maintenance job. Vervain only runs the ones that need no administrator
/// rights, and only from this fixed catalog: nothing the user types and nothing
/// read from disk ever becomes a command. Jobs that need administrator rights
/// are shown with the exact Terminal command instead.
struct MaintenanceTask: Identifiable, Sendable, Equatable {
    enum Action: Sendable, Equatable {
        case run(executable: String, arguments: [String])
        case terminal(command: String)
    }

    let taskID: MaintenanceTaskID
    let title: String
    let detail: String
    let icon: String
    let action: Action

    var id: MaintenanceTaskID { taskID }

    var terminalCommand: String? {
        if case .terminal(let command) = action { return command }
        return nil
    }

    static var all: [MaintenanceTask] {
        [
            MaintenanceTask(
                taskID: .resetQuickLook,
                title: String(localized: "Reset Quick Look previews"),
                detail: String(localized: "Clears the thumbnail and preview cache that can show stale or broken previews."),
                icon: "eye",
                action: .run(executable: "/usr/bin/qlmanage", arguments: ["-r", "cache"])),
            MaintenanceTask(
                taskID: .restartFinder,
                title: String(localized: "Restart Finder"),
                detail: String(localized: "Fixes a stuck or glitchy Finder. Finder windows close and reopen."),
                icon: "folder",
                action: .run(executable: "/usr/bin/killall", arguments: ["Finder"])),
            MaintenanceTask(
                taskID: .restartDock,
                title: String(localized: "Restart Dock"),
                detail: String(localized: "Fixes Dock, Mission Control and Spaces glitches. The screen flickers for a moment."),
                icon: "dock.rectangle",
                action: .run(executable: "/usr/bin/killall", arguments: ["Dock"])),
            MaintenanceTask(
                taskID: .restartMenuBar,
                title: String(localized: "Restart menu bar"),
                detail: String(localized: "Fixes menu bar icons and Control Center that stopped responding."),
                icon: "menubar.rectangle",
                action: .run(executable: "/usr/bin/killall", arguments: ["SystemUIServer"])),
            MaintenanceTask(
                taskID: .flushDNS,
                title: String(localized: "Flush DNS cache"),
                detail: String(localized: "Helps when a website still resolves to an old address."),
                icon: "network",
                action: .terminal(command: "sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder")),
            MaintenanceTask(
                taskID: .reindexSpotlight,
                title: String(localized: "Rebuild Spotlight index"),
                detail: String(localized: "Fixes missing search results. Indexing runs for hours and uses a lot of CPU."),
                icon: "magnifyingglass",
                action: .terminal(command: "sudo mdutil -E /")),
            MaintenanceTask(
                taskID: .purgeMemory,
                title: String(localized: "Free inactive memory"),
                detail: String(localized: "Empties the disk cache held in memory. Apps may feel slower for a moment."),
                icon: "memorychip",
                action: .terminal(command: "sudo purge"))
        ]
    }

    static func task(_ id: MaintenanceTaskID) -> MaintenanceTask? {
        all.first { $0.taskID == id }
    }
}

enum MaintenanceOutcome: Sendable, Equatable {
    case succeeded
    case failed(String)
}

actor MaintenanceRunner {

    static let timeout: Duration = .seconds(20)

    /// Runs a catalog task that needs no administrator rights. Tasks that only
    /// have a Terminal command are refused.
    func run(_ id: MaintenanceTaskID) async -> MaintenanceOutcome {
        guard let task = MaintenanceTask.task(id),
              case .run(let executable, let arguments) = task.action else {
            return .failed(String(localized: "This task needs Terminal."))
        }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        let errors = Pipe()
        process.standardOutput = FileHandle.nullDevice
        process.standardError = errors
        do {
            try process.run()
        } catch {
            return .failed(error.localizedDescription)
        }

        let deadline = ContinuousClock.now + Self.timeout
        while process.isRunning {
            if ContinuousClock.now >= deadline {
                process.terminate()
                return .failed(String(localized: "The task took too long and was stopped."))
            }
            try? await Task.sleep(for: .milliseconds(50))
        }
        if process.terminationStatus == 0 { return .succeeded }
        let message = String(decoding: errors.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return .failed(message.isEmpty ? String(localized: "The task did not finish.") : message)
    }
}
