import Foundation

actor JunkScanner {

    // MARK: - Public API

    func scan() async throws -> [JunkCategory] {
        async let caches    = scanDirectory(type: .userCaches)
        async let logs      = scanDirectory(type: .systemLogs)
        async let langFiles = scanLanguageFiles()
        async let trash     = scanDirectory(type: .trashContents)
        async let downloads = scanDownloadsFolder()

        return try await [caches, logs, langFiles, trash, downloads]
    }

    func deleteFiles(_ files: [JunkFile]) async throws -> Int64 {
        var freed: Int64 = 0
        let fm = FileManager.default
        for file in files {
            try Task.checkCancellation()
            let size = file.size
            do {
                try fm.trashItem(at: file.url, resultingItemURL: nil)
                freed += size
            } catch {
                // Skip files we can't remove (e.g. permission denied)
                continue
            }
        }
        return freed
    }

    // MARK: - Private scanning

    private func scanDirectory(type: JunkCategoryType) throws -> JunkCategory {
        guard let baseURL = type.scanPath else {
            return JunkCategory(id: type, files: [])
        }
        let fm = FileManager.default
        guard fm.fileExists(atPath: baseURL.path) else {
            return JunkCategory(id: type, files: [])
        }

        let keys: [URLResourceKey] = [.isRegularFileKey, .fileSizeKey, .localizedNameKey, .isSymbolicLinkKey]
        guard let enumerator = fm.enumerator(
            at: baseURL,
            includingPropertiesForKeys: keys,
            options: [.skipsPackageDescendants]
        ) else {
            return JunkCategory(id: type, files: [])
        }

        var files: [JunkFile] = []
        for case let fileURL as URL in enumerator {
            try Task.checkCancellation()
            guard let rv = try? fileURL.resourceValues(forKeys: Set(keys)) else { continue }
            guard rv.isSymbolicLink != true, rv.isRegularFile == true else { continue }
            let size = Int64(rv.fileSize ?? 0)
            guard size > 0 else { continue }
            let name = rv.localizedName ?? fileURL.lastPathComponent
            files.append(JunkFile(id: UUID(), url: fileURL, size: size, name: name))
        }
        return JunkCategory(id: type, files: files)
    }

    private func scanDownloadsFolder() throws -> JunkCategory {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let downloadsURL = home.appendingPathComponent("Downloads")
        let fm = FileManager.default
        guard fm.fileExists(atPath: downloadsURL.path) else {
            return JunkCategory(id: .downloads, files: [])
        }

        let contents = (try? fm.contentsOfDirectory(
            at: downloadsURL,
            includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey],
            options: [.skipsHiddenFiles]
        )) ?? []

        var files: [JunkFile] = []
        for itemURL in contents {
            try Task.checkCancellation()
            let size = directorySize(at: itemURL)
            guard size > 0 else { continue }
            files.append(JunkFile(
                id: UUID(),
                url: itemURL,
                size: size,
                name: itemURL.lastPathComponent
            ))
        }
        return JunkCategory(id: .downloads, files: files)
    }

    private func scanLanguageFiles() throws -> JunkCategory {
        let fm = FileManager.default
        let preferredLangs = Set(Locale.preferredLanguages.map { lang -> String in
            // Normalize "en-US" → "en", "zh-Hans" → "zh"
            let base = lang.components(separatedBy: CharacterSet(charactersIn: "-_")).first ?? lang
            return base
        })

        let appsURL = URL(fileURLWithPath: "/Applications")
        guard let appBundles = try? fm.contentsOfDirectory(
            at: appsURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return JunkCategory(id: .languageFiles, files: [])
        }

        var files: [JunkFile] = []
        for appURL in appBundles where appURL.pathExtension == "app" {
            try Task.checkCancellation()
            let resourcesURL = appURL.appendingPathComponent("Contents/Resources")
            guard let lprojDirs = try? fm.contentsOfDirectory(
                at: resourcesURL,
                includingPropertiesForKeys: nil,
                options: []
            ) else { continue }

            let appDisplayName = appURL.deletingPathExtension().lastPathComponent

            for lproj in lprojDirs where lproj.pathExtension == "lproj" {
                let langCode = lproj.deletingPathExtension().lastPathComponent
                // Keep "Base" and any language the user prefers
                if langCode == "Base" { continue }
                let base = langCode.components(separatedBy: CharacterSet(charactersIn: "-_")).first ?? langCode
                if preferredLangs.contains(base) { continue }

                let size = directorySize(at: lproj)
                guard size > 0 else { continue }
                files.append(JunkFile(
                    id: UUID(),
                    url: lproj,
                    size: size,
                    name: "\(appDisplayName) – \(langCode)"
                ))
            }
        }
        return JunkCategory(id: .languageFiles, files: files)
    }
}
