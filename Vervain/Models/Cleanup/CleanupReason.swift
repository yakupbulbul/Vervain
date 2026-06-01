import Foundation

/// Why a file ended up in the cleanup list — shown to the user verbatim.
enum CleanupReason: Sendable, Hashable {
    case oldCache(ageDays: Int)
    case recentCache
    case oldLog(ageDays: Int)
    case recentLog
    case languageFile(language: String, app: String)
    case trashItem
    case oldDownload(ageDays: Int)
    case download(extension: String)
    case appBundle
    case appLeftover(bundleID: String)
    case duplicate(of: String)
    case largeOldFile(ageDays: Int)
    case browserCache(browser: String)
    case browserHistory(browser: String)
    case browserCookies(browser: String)
    case custom(String)

    var displayText: String {
        switch self {
        case .oldCache(let days):             return "Cache file unused for \(days) days"
        case .recentCache:                    return "Recently accessed cache file"
        case .oldLog(let days):               return "Log file older than \(days) days"
        case .recentLog:                      return "Recent log file"
        case .languageFile(let lang, let app):return "Unused \(lang) translation in \(app)"
        case .trashItem:                      return "Already in Trash"
        case .oldDownload(let days):          return "Download from \(days) days ago"
        case .download(let ext):              return "Downloaded .\(ext) file"
        case .appBundle:                      return "Application bundle"
        case .appLeftover(let id):            return "Leftover from \(id)"
        case .duplicate(let original):        return "Duplicate of \(original)"
        case .largeOldFile(let days):         return "Large file unused for \(days) days"
        case .browserCache(let browser):      return "\(browser) cache"
        case .browserHistory(let browser):    return "\(browser) browsing history"
        case .browserCookies(let browser):    return "\(browser) cookies"
        case .custom(let text):               return text
        }
    }
}
