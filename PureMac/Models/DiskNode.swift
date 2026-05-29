import SwiftUI

enum DiskCategory: String, CaseIterable, Sendable {
    case applications = "Applications"
    case documents    = "Documents"
    case media        = "Media"
    case developer    = "Developer"
    case library      = "Library"
    case other        = "Other"

    var color: Color {
        switch self {
        case .applications: return Theme.chartApplications
        case .documents:    return Theme.chartDocuments
        case .media:        return Theme.chartMedia
        case .developer:    return Theme.chartDeveloper
        case .library:      return Theme.chartLibrary
        case .other:        return Theme.chartOther
        }
    }
}

final class DiskNode: Identifiable, @unchecked Sendable {
    let id: UUID = UUID()
    let url: URL
    let name: String
    var size: Int64
    var children: [DiskNode]
    let isDirectory: Bool

    init(url: URL, name: String, size: Int64, children: [DiskNode], isDirectory: Bool) {
        self.url = url
        self.name = name
        self.size = size
        self.children = children
        self.isDirectory = isDirectory
    }

    var category: DiskCategory {
        switch name.lowercased() {
        case "applications":                         return .applications
        case "documents", "desktop", "downloads":    return .documents
        case "movies", "music", "pictures":          return .media
        case "developer", "xcode", "simulators":     return .developer
        case "library":                              return .library
        case "users":                                return .documents  // personal data
        case "opt", "usr":                           return .developer  // unix / homebrew tools
        case "system", "var", "private",
             "system & other":                       return .other
        default:                                     return .other
        }
    }
}
