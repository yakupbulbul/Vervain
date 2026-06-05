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
        case .oldCache(let days):             return String(localized: "Cache file unused for \(days) days")
        case .recentCache:                    return String(localized: "Recently accessed cache file")
        case .oldLog(let days):               return String(localized: "Log file older than \(days) days")
        case .recentLog:                      return String(localized: "Recent log file")
        case .languageFile(let lang, let app):return String(localized: "Unused \(lang) translation in \(app)")
        case .trashItem:                      return String(localized: "Already in Trash")
        case .oldDownload(let days):          return String(localized: "Download from \(days) days ago")
        case .download(let ext):              return String(localized: "Downloaded .\(ext) file")
        case .appBundle:                      return String(localized: "Application bundle")
        case .appLeftover(let id):            return String(localized: "Leftover from \(id)")
        case .duplicate(let original):        return String(localized: "Duplicate of \(original)")
        case .largeOldFile(let days):         return String(localized: "Large file unused for \(days) days")
        case .browserCache(let browser):      return String(localized: "\(browser) cache")
        case .browserHistory(let browser):    return String(localized: "\(browser) browsing history")
        case .browserCookies(let browser):    return String(localized: "\(browser) cookies")
        case .custom(let text):               return text
        }
    }
}
