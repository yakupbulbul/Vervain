import XCTest

/// Reads the string catalog straight from the source tree, so a missing or
/// broken translation fails here instead of showing up as English in the app.
final class LocalizationCatalogTests: XCTestCase {

    private static let languages = ["de", "es", "fr", "ja", "ko", "tr", "zh-Hans"]

    private struct Catalog: Decodable {
        struct Entry: Decodable {
            struct Localization: Decodable {
                struct Unit: Decodable {
                    let state: String
                    let value: String
                }
                let stringUnit: Unit?
            }
            let localizations: [String: Localization]?
        }
        let strings: [String: Entry]
    }

    private func loadCatalog() throws -> Catalog {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let url = root.appendingPathComponent("Vervain/Localizable.xcstrings")
        return try JSONDecoder().decode(Catalog.self, from: Data(contentsOf: url))
    }

    /// `%@`, `%lld`, `%d` and `%%`, in the order they appear.
    private func placeholders(in text: String) -> [String] {
        let pattern = #"%(?:\d+\$)?(?:lld|ld|d|@|f|%)"#
        let regex = try! NSRegularExpression(pattern: pattern)
        let range = NSRange(text.startIndex..., in: text)
        return regex.matches(in: text, range: range).map {
            String(text[Range($0.range, in: text)!])
                .replacingOccurrences(of: #"\d+\$"#, with: "", options: .regularExpression)
        }
    }

    func testEveryStringIsTranslatedIntoEveryLanguage() throws {
        let catalog = try loadCatalog()
        var problems: [String] = []
        for (key, entry) in catalog.strings {
            for language in Self.languages {
                guard let unit = entry.localizations?[language]?.stringUnit else {
                    problems.append("\(language) missing: \(key)")
                    continue
                }
                if unit.state != "translated" { problems.append("\(language) \(unit.state): \(key)") }
                if unit.value.trimmingCharacters(in: .whitespaces).isEmpty {
                    problems.append("\(language) empty: \(key)")
                }
            }
        }
        XCTAssertTrue(problems.isEmpty, problems.sorted().prefix(20).joined(separator: "\n"))
    }

    func testTranslationsKeepTheSamePlaceholdersAsEnglish() throws {
        let catalog = try loadCatalog()
        var problems: [String] = []
        for (key, entry) in catalog.strings {
            let expected = placeholders(in: key).sorted()
            for language in Self.languages {
                guard let value = entry.localizations?[language]?.stringUnit?.value else { continue }
                if placeholders(in: value).sorted() != expected {
                    problems.append("\(language): \(key) -> \(value)")
                }
            }
        }
        XCTAssertTrue(problems.isEmpty, problems.sorted().prefix(20).joined(separator: "\n"))
    }
}
