import Foundation

/// Finds locally stored machine-learning models and their download caches
/// (Hugging Face, LM Studio, Ollama, PyTorch, Whisper, Keras, GPT4All).
///
/// These often add up to tens of gigabytes. They can be downloaded again, but
/// slowly and sometimes at a cost, so every item is `.review` and nothing is
/// pre-selected. Models are listed one by one so the user picks which to drop.
actor AIModelsScanner {

    static let minimumSize: Int64 = 10_000_000
    static let concurrency = 4

    enum Group: Int, CaseIterable, Sendable {
        case huggingFace, lmStudio, ollama, other

        var title: String {
            switch self {
            case .huggingFace: return String(localized: "Hugging Face")
            case .lmStudio:    return String(localized: "LM Studio")
            case .ollama:      return String(localized: "Ollama")
            case .other:       return String(localized: "Other AI Tools")
            }
        }

        var subtitle: String {
            switch self {
            case .huggingFace: return String(localized: "Cached models and datasets — downloaded again on first use")
            case .lmStudio:    return String(localized: "Models you downloaded in LM Studio")
            case .ollama:      return String(localized: "All Ollama models in one item. To remove a single model, run ollama rm in Terminal.")
            case .other:       return String(localized: "PyTorch, Whisper, Keras, GPT4All and similar downloads")
            }
        }

        var icon: String {
            switch self {
            case .huggingFace: return "face.smiling"
            case .lmStudio:    return "desktopcomputer"
            case .ollama:      return "shippingbox"
            case .other:       return "brain"
            }
        }
    }

    struct Candidate: Sendable {
        let url: URL
        let name: String
        let group: Group
        let reason: String
    }

    func scan(
        home: URL = FileManager.default.homeDirectoryForCurrentUser
    ) async throws -> (categories: [CleanupCategory], metadata: ScanMetadata) {
        let started = Date()
        var meta = ScanMetadata()
        let candidates = try Self.candidates(home: home)

        var itemsByGroup: [Group: [CleanupItem]] = [:]
        try await withThrowingTaskGroup(of: (Group, CleanupItem?).self) { group in
            var iterator = candidates.makeIterator()
            func addNext() -> Bool {
                guard let candidate = iterator.next() else { return false }
                group.addTask { (candidate.group, Self.measure(candidate)) }
                return true
            }
            var running = 0
            while running < Self.concurrency, addNext() { running += 1 }
            while let (key, item) = try await group.next() {
                try Task.checkCancellation()
                if let item { itemsByGroup[key, default: []].append(item) }
                _ = addNext()
            }
        }

        var categories: [CleanupCategory] = []
        for key in Group.allCases {
            guard let items = itemsByGroup[key], !items.isEmpty else { continue }
            categories.append(CleanupCategory(
                kind: .aiModels,
                title: key.title,
                subtitle: key.subtitle,
                icon: key.icon,
                sourceModule: .aiModels,
                items: items.sorted { $0.size > $1.size }
            ))
        }
        categories.sort { $0.totalSize > $1.totalSize }

        meta.scannedCount = categories.reduce(0) { $0 + $1.itemCount }
        meta.duration = Date().timeIntervalSince(started)
        return (categories, meta)
    }

    // MARK: - Discovery

    static func candidates(home: URL) throws -> [Candidate] {
        let fm = FileManager.default
        var result: [Candidate] = []

        func children(of url: URL) -> [URL] {
            guard let urls = try? fm.contentsOfDirectory(
                at: url, includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey], options: [.skipsHiddenFiles]
            ) else { return [] }
            return urls.filter { url in
                let rv = try? url.resourceValues(forKeys: [.isSymbolicLinkKey])
                return rv?.isSymbolicLink != true
            }
        }

        // Hugging Face: one folder per repository, named models--org--name.
        let hub = home.appendingPathComponent(".cache/huggingface/hub")
        for entry in children(of: hub) {
            try Task.checkCancellation()
            let folder = entry.lastPathComponent
            guard let prefix = ["models--", "datasets--", "spaces--"].first(where: folder.hasPrefix) else { continue }
            let name = folder.dropFirst(prefix.count).replacingOccurrences(of: "--", with: "/")
            result.append(Candidate(
                url: entry, name: name, group: .huggingFace,
                reason: String(localized: "Hugging Face download — fetched again the next time it is used")
            ))
        }

        // LM Studio: models/<publisher>/<model>, in its current and older location.
        for base in [".lmstudio/models", ".cache/lm-studio/models"] {
            for publisher in children(of: home.appendingPathComponent(base)) {
                try Task.checkCancellation()
                for model in children(of: publisher) {
                    result.append(Candidate(
                        url: model, name: "\(publisher.lastPathComponent)/\(model.lastPathComponent)",
                        group: .lmStudio,
                        reason: String(localized: "LM Studio model — download it again from LM Studio")
                    ))
                }
            }
        }

        // Ollama stores shared blobs, so removing one model alone would break others.
        let ollama = home.appendingPathComponent(".ollama/models")
        if fm.fileExists(atPath: ollama.path) {
            result.append(Candidate(
                url: ollama, name: String(localized: "All Ollama models"), group: .ollama,
                reason: String(localized: "Ollama models — pull them again with ollama pull")
            ))
        }

        let others: [(String, String)] = [
            (".cache/torch", String(localized: "PyTorch downloads")),
            (".cache/whisper", String(localized: "Whisper models")),
            (".keras", String(localized: "Keras models and datasets")),
            ("Library/Application Support/nomic.ai/GPT4All", String(localized: "GPT4All models"))
        ]
        for (path, title) in others {
            let url = home.appendingPathComponent(path)
            guard fm.fileExists(atPath: url.path) else { continue }
            result.append(Candidate(
                url: url, name: title, group: .other,
                reason: String(localized: "Downloaded model files — fetched again when a tool needs them")
            ))
        }
        return result
    }

    private static func measure(_ candidate: Candidate) -> CleanupItem? {
        let stats = directoryStats(at: candidate.url)
        guard stats.size >= minimumSize else { return nil }
        return CleanupItem(
            url: candidate.url,
            name: candidate.name,
            size: stats.size,
            category: candidate.group.title,
            reason: .custom(candidate.reason),
            riskLevel: .review,
            confidenceLevel: .medium,
            lastModifiedDate: stats.newestModification == .distantPast ? nil : stats.newestModification,
            sourceModule: .aiModels
        )
    }
}
