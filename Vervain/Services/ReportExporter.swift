import Foundation
import AppKit
import UniformTypeIdentifiers

/// Turns scan results into a CSV or Markdown report the user can keep.
/// Formatting is pure (testable); only `save` touches the UI.
enum ReportExporter {

    enum Format {
        case csv, markdown

        var fileExtension: String { self == .csv ? "csv" : "md" }
        var contentType: UTType { self == .csv ? .commaSeparatedText : .plainText }
    }

    static func csv(for categories: [CleanupCategory]) -> String {
        let header = ["Category", "Name", "Path", "Size (bytes)", "Risk", "Confidence",
                      "Reason", "Last modified", "Selected"]
        var lines = [header.map(escape).joined(separator: ",")]
        let formatter = ISO8601DateFormatter()
        for category in categories {
            for item in category.items {
                let fields = [
                    category.title,
                    item.name,
                    item.url.path,
                    String(item.size),
                    item.riskLevel.rawValue,
                    item.confidenceLevel.rawValue,
                    item.reason.displayText,
                    item.lastModifiedDate.map { formatter.string(from: $0) } ?? "",
                    item.isSelected ? "yes" : "no",
                ]
                lines.append(fields.map(escape).joined(separator: ","))
            }
        }
        return lines.joined(separator: "\n") + "\n"
    }

    static func markdown(for categories: [CleanupCategory], title: String) -> String {
        let total = categories.reduce(Int64(0)) { $0 + $1.totalSize }
        var out = ["# \(title)", "", "Total: \(total.formattedBytes) in \(categories.reduce(0) { $0 + $1.itemCount }) items", ""]
        for category in categories {
            out.append("## \(category.title) — \(category.totalSize.formattedBytes)")
            out.append("")
            for item in category.items {
                out.append("- `\(item.displayPath)` — \(item.size.formattedBytes) — \(item.riskLevel.rawValue)")
            }
            out.append("")
        }
        return out.joined(separator: "\n")
    }

    /// RFC 4180 quoting: wrap in quotes when needed and double embedded quotes.
    static func escape(_ field: String) -> String {
        guard field.contains(where: { $0 == "," || $0 == "\"" || $0 == "\n" || $0 == "\r" }) else { return field }
        return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    @MainActor
    static func save(categories: [CleanupCategory], title: String, format: Format) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [format.contentType]
        panel.nameFieldStringValue = "Vervain Report.\(format.fileExtension)"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let text = format == .csv ? csv(for: categories) : markdown(for: categories, title: title)
        try? text.write(to: url, atomically: true, encoding: .utf8)
    }
}
