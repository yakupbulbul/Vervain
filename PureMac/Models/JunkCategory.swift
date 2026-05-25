import Foundation

enum JunkCategoryType: String, CaseIterable, Identifiable, Sendable {
    case userCaches    = "User Caches"
    case systemLogs    = "System Logs"
    case languageFiles = "Language Files"
    case trashContents = "Trash Contents"
    case downloads     = "Downloads Folder"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .userCaches:    return "internaldrive"
        case .systemLogs:    return "doc.text.fill"
        case .languageFiles: return "globe"
        case .trashContents: return "trash.fill"
        case .downloads:     return "arrow.down.circle.fill"
        }
    }

    var scanPath: URL? {
        let home = FileManager.default.homeDirectoryForCurrentUser
        switch self {
        case .userCaches:    return home.appendingPathComponent("Library/Caches")
        case .systemLogs:    return home.appendingPathComponent("Library/Logs")
        case .languageFiles: return URL(fileURLWithPath: "/Applications")
        case .trashContents: return home.appendingPathComponent(".Trash")
        case .downloads:     return home.appendingPathComponent("Downloads")
        }
    }
}

struct JunkFile: Identifiable, Sendable {
    let id: UUID
    let url: URL
    let size: Int64
    let name: String
}

struct JunkCategory: Identifiable, Sendable {
    let id: JunkCategoryType
    var files: [JunkFile]
    var isSelected: Bool = true

    var totalSize: Int64 {
        files.reduce(0) { $0 + $1.size }
    }
}
