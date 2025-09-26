import Foundation
import Domain

/// Service responsible for formatting documents in various formats
public final class DocumentFormatter {

    public init() {}

    /// Format content for the specified format
    public func formatContent(_ content: String, for format: DocumentFormat) -> String {
        switch format {
        case .markdown:
            return content
        case .html:
            return convertMarkdownToHTML(content)
        case .json:
            return wrapInJSON(content)
        case .pdf, .docx:
            return content // These would need specialized formatting libraries
        }
    }

    /// Generate filename for export
    public func generateFilename(_ title: String, format: DocumentFormat) -> String {
        let sanitizedTitle = sanitizeFilename(title)
        let timestamp = generateTimestamp()
        return "\(sanitizedTitle)_\(timestamp).\(format.rawValue)"
    }

    /// Get MIME type for format
    public func getMimeType(for format: DocumentFormat) -> String {
        switch format {
        case .markdown:
            return "text/markdown"
        case .html:
            return "text/html"
        case .pdf:
            return "application/pdf"
        case .docx:
            return "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
        case .json:
            return "application/json"
        }
    }

    // MARK: - Private Methods

    private func convertMarkdownToHTML(_ markdown: String) -> String {
        // Simple conversion - in production, use a proper markdown parser
        let escapedMarkdown = escapeHTMLCharacters(markdown)
        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <title>PRD Document</title>
            <style>
                body { font-family: Arial, sans-serif; padding: 20px; }
                pre { background: #f4f4f4; padding: 10px; border-radius: 5px; }
            </style>
        </head>
        <body>
            <pre>\(escapedMarkdown)</pre>
        </body>
        </html>
        """
    }

    private func wrapInJSON(_ content: String) -> String {
        let jsonData: [String: Any] = [
            "content": content,
            "format": "markdown",
            "generatedAt": ISO8601DateFormatter().string(from: Date())
        ]

        guard let data = try? JSONSerialization.data(withJSONObject: jsonData, options: .prettyPrinted),
              let jsonString = String(data: data, encoding: .utf8) else {
            // Fallback to simple JSON if serialization fails
            let escapedContent = content.replacingOccurrences(of: "\"", with: "\\\"")
            return "{\"content\": \"\(escapedContent)\"}"
        }

        return jsonString
    }

    private func sanitizeFilename(_ title: String) -> String {
        let allowedCharacterSet = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        return title.components(separatedBy: allowedCharacterSet.inverted)
            .joined(separator: "_")
            .trimmingCharacters(in: .whitespaces)
            .prefix(50) // Limit filename length
            .lowercased()
    }

    private func generateTimestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        return formatter.string(from: Date())
    }

    private func escapeHTMLCharacters(_ text: String) -> String {
        return text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }
}