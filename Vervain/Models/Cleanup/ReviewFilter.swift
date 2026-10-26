import Foundation

/// Search, sort and file-type filter applied to the items in the review sheet.
/// Pure value type so it can be unit-tested without any UI.
struct ReviewFilter: Equatable, Sendable {

    enum Sort: String, CaseIterable, Identifiable, Sendable {
        case scanOrder
        case sizeDescending
        case nameAscending
        case oldestFirst

        var id: String { rawValue }

        var label: String {
            switch self {
            case .scanOrder:      return String(localized: "Scan order")
            case .sizeDescending: return String(localized: "Largest first")
            case .nameAscending:  return String(localized: "Name")
            case .oldestFirst:    return String(localized: "Oldest first")
            }
        }
    }

    enum FileKind: String, CaseIterable, Identifiable, Sendable {
        case all, video, audio, image, archive, diskImage, document, other

        var id: String { rawValue }

        var label: String {
            switch self {
            case .all:       return String(localized: "All types")
            case .video:     return String(localized: "Video")
            case .audio:     return String(localized: "Audio")
            case .image:     return String(localized: "Images")
            case .archive:   return String(localized: "Archives")
            case .diskImage: return String(localized: "Disk images & installers")
            case .document:  return String(localized: "Documents")
            case .other:     return String(localized: "Other")
            }
        }
    }

    var query: String = ""
    var sort: Sort = .scanOrder
    var kind: FileKind = .all

    /// True if anything narrows or reorders the list.
    var isActive: Bool {
        !query.trimmingCharacters(in: .whitespaces).isEmpty || kind != .all
    }

    func apply(to items: [CleanupItem]) -> [CleanupItem] {
        let needle = query.trimmingCharacters(in: .whitespaces)
        var result = items.filter { item in
            if kind != .all && Self.kind(of: item.url) != kind { return false }
            if needle.isEmpty { return true }
            return item.name.localizedCaseInsensitiveContains(needle)
                || item.displayPath.localizedCaseInsensitiveContains(needle)
        }
        switch sort {
        case .scanOrder:
            break
        case .sizeDescending:
            result.sort { $0.size > $1.size }
        case .nameAscending:
            result.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        case .oldestFirst:
            result.sort { lhs, rhs in
                switch (lhs.lastModifiedDate, rhs.lastModifiedDate) {
                case let (l?, r?): return l < r
                case (_?, nil):    return true
                default:           return false
                }
            }
        }
        return result
    }

    static func kind(of url: URL) -> FileKind {
        let ext = url.pathExtension.lowercased()
        if videoExtensions.contains(ext)     { return .video }
        if audioExtensions.contains(ext)     { return .audio }
        if imageExtensions.contains(ext)     { return .image }
        if archiveExtensions.contains(ext)   { return .archive }
        if diskImageExtensions.contains(ext) { return .diskImage }
        if documentExtensions.contains(ext)  { return .document }
        return .other
    }

    private static let videoExtensions: Set<String> = ["mp4", "mov", "m4v", "avi", "mkv", "webm", "wmv"]
    private static let audioExtensions: Set<String> = ["mp3", "m4a", "wav", "aac", "flac", "aiff", "ogg"]
    private static let imageExtensions: Set<String> = [
        "jpg", "jpeg", "png", "gif", "heic", "heif", "tiff", "bmp", "webp", "raw", "cr2", "nef", "dng", "psd"
    ]
    private static let archiveExtensions: Set<String> = ["zip", "rar", "7z", "tar", "gz", "tgz", "bz2", "xz"]
    private static let diskImageExtensions: Set<String> = ["dmg", "iso", "pkg", "img"]
    private static let documentExtensions: Set<String> = [
        "pdf", "doc", "docx", "xls", "xlsx", "ppt", "pptx", "pages", "numbers", "key", "txt", "rtf", "md", "csv"
    ]
}
