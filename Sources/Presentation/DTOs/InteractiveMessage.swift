import Foundation
import Vapor
import Domain

/// Interactive message for WebSocket communication
public struct InteractiveMessage: Content {
    public let type: String
    public let message: String?
    public let questions: [String]?
    public let generateCommand: GeneratePRDCommand?
    public let answers: [String]?
    public let result: PRDDocumentDTO?
    public let section: SectionUpdate?

    public let title: String?
    public let description: String?
    public let priority: String?

    public init(
        type: String,
        message: String? = nil,
        questions: [String]? = nil,
        generateCommand: GeneratePRDCommand? = nil,
        answers: [String]? = nil,
        result: PRDDocumentDTO? = nil,
        section: SectionUpdate? = nil,
        title: String? = nil,
        description: String? = nil,
        priority: String? = nil
    ) {
        self.type = type
        self.message = message
        self.questions = questions
        self.generateCommand = generateCommand
        self.answers = answers
        self.result = result
        self.section = section
        self.title = title
        self.description = description
        self.priority = priority
    }
}

public struct SectionUpdate: Content {
    public let id: String
    public let title: String
    public let content: String
    public let order: Int

    public init(id: String, title: String, content: String, order: Int) {
        self.id = id
        self.title = title
        self.content = content
        self.order = order
    }
}