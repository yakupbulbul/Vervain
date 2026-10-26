import Foundation

/// Manual "Check for Updates". Nothing runs in the background: the only
/// network request Vervain ever makes is the one the user triggers from
/// Settings, a single GET to the project's public GitHub releases API.
enum UpdateChecker {

    enum Outcome: Equatable, Sendable {
        case upToDate
        case available(version: String, url: URL)
        case failed
    }

    private struct Release: Decodable {
        let tagName: String
        let htmlURL: URL

        enum CodingKeys: String, CodingKey {
            case tagName = "tag_name"
            case htmlURL = "html_url"
        }
    }

    static let latestReleaseURL = URL(string: "https://api.github.com/repos/yakupbulbul/Vervain/releases/latest")!

    static func check(
        current: String,
        session: URLSession = .shared,
        endpoint: URL = latestReleaseURL
    ) async -> Outcome {
        var request = URLRequest(url: endpoint, timeoutInterval: 15)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        do {
            let (data, response) = try await session.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { return .failed }
            let release = try JSONDecoder().decode(Release.self, from: data)
            return isNewer(release.tagName, than: current)
                ? .available(version: normalized(release.tagName), url: release.htmlURL)
                : .upToDate
        } catch {
            return .failed
        }
    }

    /// Compares dotted numeric versions ("v2.0.1" > "2.0"). Missing parts count as 0.
    static func isNewer(_ remote: String, than local: String) -> Bool {
        let r = components(of: remote)
        let l = components(of: local)
        for i in 0..<max(r.count, l.count) {
            let a = i < r.count ? r[i] : 0
            let b = i < l.count ? l[i] : 0
            if a != b { return a > b }
        }
        return false
    }

    static func normalized(_ version: String) -> String {
        version.hasPrefix("v") || version.hasPrefix("V") ? String(version.dropFirst()) : version
    }

    private static func components(of version: String) -> [Int] {
        normalized(version).split(separator: ".").map { part in
            Int(part.prefix { $0.isNumber }) ?? 0
        }
    }
}
