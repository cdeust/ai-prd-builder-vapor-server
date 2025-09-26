import Foundation
import Domain
import CommonModels
import PRDGenerator

struct PRDConverter {
    private let sectionExtractor = SectionExtractor()

    func convert(
        prdDocument: PRDocument,
        processingTime: TimeInterval,
        providerName: String
    ) throws -> PRDGenerationResult {
        let sections = prdDocument.sections.map { section in
            GeneratedSection(
                title: section.title,
                content: section.content,
                type: sectionExtractor.mapSectionType(section.title)
            )
        }

        let metadata = GenerationMetadata(
            provider: providerName,
            modelVersion: "1.0.0",
            processingTime: processingTime,
            tokensUsed: nil,
            cost: nil
        )

        let formattedContent = generateFormattedContent(from: prdDocument)

        return PRDGenerationResult(
            content: formattedContent,
            sections: sections,
            confidence: 0.95,
            metadata: metadata
        )
    }

    func convertToExportDocument(
        _ result: PRDGenerationResult,
        format: ExportFormat
    ) -> (sections: [CommonModels.PRDSection], title: String) {
        let sections = result.sections.map { section in
            CommonModels.PRDSection(
                title: section.title,
                content: section.content,
                subsections: []
            )
        }

        let title = sections.first?.title ?? "Product Requirements Document"
        return (sections, title)
    }

    func mapExportFormat(_ format: ExportFormat) -> PRDExporter.ExportFormat {
        switch format {
        case .markdown:
            return .markdown
        case .json:
            return .json
        case .html:
            return .html
        case .pdf:
            return .html
        }
    }

    private func generateFormattedContent(from document: PRDocument) -> String {
        var content = "# \(document.title)\n\n"

        for section in document.sections {
            content += formatSection(section, level: 2)
        }

        return content
    }

    private func formatSection(_ section: CommonModels.PRDSection, level: Int) -> String {
        let headerPrefix = String(repeating: "#", count: level)
        var formatted = "\(headerPrefix) \(section.title)\n\n"
        formatted += "\(section.content)\n\n"

        for subsection in section.subsections {
            formatted += formatSection(subsection, level: level + 1)
        }

        return formatted
    }
}