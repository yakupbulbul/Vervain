import AppIntents
import Foundation

/// Read-only actions for the Shortcuts app and Spotlight. None of them
/// deletes anything or touches the network.

struct FreeSpaceIntent: AppIntent {
    static let title: LocalizedStringResource = "Get Free Disk Space"
    static let description = IntentDescription("Returns how much space is free on the startup disk.")

    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        guard let usage = DiskUsage.current() else {
            throw IntentError.unavailable
        }
        let text = String(localized: "\(usage.available.formattedBytes) free of \(usage.total.formattedBytes)")
        return .result(value: text, dialog: IntentDialog(stringLiteral: text))
    }
}

struct TrashSizeIntent: AppIntent {
    static let title: LocalizedStringResource = "Get Trash Size"
    static let description = IntentDescription("Returns how much space the Trash is using.")

    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let trash = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".Trash")
        let text = directorySize(at: trash).formattedBytes
        return .result(value: text, dialog: IntentDialog(stringLiteral: text))
    }
}

struct StartSmartScanIntent: AppIntent {
    static let title: LocalizedStringResource = "Start Smart Scan"
    static let description = IntentDescription("Opens Vervain and starts a Smart Scan. Nothing is cleaned without your review.")
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        NotificationCenter.default.post(name: NotificationRouter.startScanNotification, object: nil)
        return .result()
    }
}

enum IntentError: Error, CustomLocalizedStringResourceConvertible {
    case unavailable

    var localizedStringResource: LocalizedStringResource {
        "The disk information is not available."
    }
}

struct VervainShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: FreeSpaceIntent(), phrases: ["Free space in \(.applicationName)"],
                    shortTitle: "Free Space", systemImageName: "internaldrive")
        AppShortcut(intent: StartSmartScanIntent(), phrases: ["Scan with \(.applicationName)"],
                    shortTitle: "Smart Scan", systemImageName: "leaf")
    }
}
