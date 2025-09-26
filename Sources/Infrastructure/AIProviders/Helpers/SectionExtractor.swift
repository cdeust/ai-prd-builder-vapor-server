import Foundation
import Domain

struct SectionExtractor {
    func extractSections(from content: String) -> [GeneratedSection] {
        let lines = content.components(separatedBy: .newlines)
        var sections: [GeneratedSection] = []
        var currentTitle = ""
        var currentContent = ""
        var currentType = "general"

        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)

            if trimmedLine.hasPrefix("# ") || trimmedLine.hasPrefix("## ") || trimmedLine.hasPrefix("### ") {
                if !currentTitle.isEmpty {
                    sections.append(GeneratedSection(
                        title: currentTitle,
                        content: currentContent.trimmingCharacters(in: .whitespacesAndNewlines),
                        type: currentType
                    ))
                }

                currentTitle = trimmedLine.replacingOccurrences(of: "^#+\\s*", with: "", options: .regularExpression)
                currentContent = ""
                currentType = inferSectionType(from: currentTitle)
            } else {
                currentContent += line + "\n"
            }
        }

        if !currentTitle.isEmpty {
            sections.append(GeneratedSection(
                title: currentTitle,
                content: currentContent.trimmingCharacters(in: .whitespacesAndNewlines),
                type: currentType
            ))
        }

        return sections
    }

    func mapSectionType(_ title: String) -> String {
        let lowercased = title.lowercased()

        if lowercased.contains("executive") || lowercased.contains("summary") {
            return "executive_summary"
        } else if lowercased.contains("problem") {
            return "problem_statement"
        } else if lowercased.contains("user stor") {
            return "user_stories"
        } else if lowercased.contains("functional req") {
            return "functional_requirements"
        } else if lowercased.contains("non-functional") || lowercased.contains("nfr") {
            return "non_functional_requirements"
        } else if lowercased.contains("technical") {
            return "technical_requirements"
        } else if lowercased.contains("acceptance") || lowercased.contains("criteria") {
            return "acceptance_criteria"
        } else if lowercased.contains("timeline") || lowercased.contains("schedule") {
            return "timeline"
        } else if lowercased.contains("risk") {
            return "risks"
        } else if lowercased.contains("appendix") || lowercased.contains("addendum") {
            return "appendix"
        } else {
            return "other"
        }
    }

    private func inferSectionType(from title: String) -> String {
        let lowercased = title.lowercased()

        if lowercased.contains("executive") || lowercased.contains("summary") {
            return "executive_summary"
        } else if lowercased.contains("problem") {
            return "problem_statement"
        } else if lowercased.contains("user stories") || lowercased.contains("stories") {
            return "user_stories"
        } else if lowercased.contains("functional requirements") || lowercased.contains("functional") {
            return "functional_requirements"
        } else if lowercased.contains("non-functional") || lowercased.contains("performance") {
            return "non_functional_requirements"
        } else if lowercased.contains("technical") {
            return "technical_requirements"
        } else if lowercased.contains("acceptance") {
            return "acceptance_criteria"
        } else if lowercased.contains("timeline") {
            return "timeline"
        } else if lowercased.contains("risks") {
            return "risks"
        } else {
            return "general"
        }
    }
}