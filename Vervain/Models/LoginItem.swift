import Foundation

/// A background job that macOS starts automatically (a launchd agent or daemon).
struct LoginItem: Identifiable, Sendable, Hashable {

    enum Scope: String, Sendable, Hashable {
        case userAgent       // ~/Library/LaunchAgents
        case systemAgent     // /Library/LaunchAgents
        case systemDaemon    // /Library/LaunchDaemons

        var displayName: String {
            switch self {
            case .userAgent:    return String(localized: "Your launch agents")
            case .systemAgent:  return String(localized: "Launch agents for all users")
            case .systemDaemon: return String(localized: "System daemons")
            }
        }
    }

    let id: String          // plist path
    let label: String
    let program: String?
    let plistURL: URL
    let scope: Scope
    let runsAtLoad: Bool
    let isDisabled: Bool

    /// Only items in the user's own LaunchAgents folder can be trashed
    /// without administrator rights, so only those are offered for removal.
    var isRemovable: Bool { scope == .userAgent }
}
