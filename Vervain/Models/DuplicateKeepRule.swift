import Foundation

/// Which copy of a duplicate group is kept (and never offered for removal).
enum DuplicateKeepRule: String, CaseIterable, Identifiable, Sendable {
    case oldest
    case newest
    case shortestPath

    static let defaultsKey = "duplicateKeepRule"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .oldest:       return String(localized: "Keep the oldest")
        case .newest:       return String(localized: "Keep the newest")
        case .shortestPath: return String(localized: "Keep the one in the shallowest folder")
        }
    }

    var keptDescription: String {
        switch self {
        case .oldest:       return String(localized: "the oldest is kept")
        case .newest:       return String(localized: "the newest is kept")
        case .shortestPath: return String(localized: "the one in the shallowest folder is kept")
        }
    }

    static func fromDefaults(_ defaults: UserDefaults = .standard) -> DuplicateKeepRule {
        defaults.string(forKey: defaultsKey).flatMap(DuplicateKeepRule.init(rawValue:)) ?? .oldest
    }

    /// True if the first file should sort ahead of (be kept before) the second.
    func isBetterToKeep(_ lhsPath: String, _ lhsDate: Date, than rhsPath: String, _ rhsDate: Date) -> Bool {
        switch self {
        case .oldest:
            return lhsDate < rhsDate
        case .newest:
            return lhsDate > rhsDate
        case .shortestPath:
            let l = lhsPath.split(separator: "/").count, r = rhsPath.split(separator: "/").count
            return l != r ? l < r : lhsDate < rhsDate
        }
    }
}
