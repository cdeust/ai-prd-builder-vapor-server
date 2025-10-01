import Foundation
import Vapor
import Domain

/// Interactive message for WebSocket communication
public struct InteractiveMessageDTO: Content {
    public let type: String
    public let message: String?
    public let questions: [String]?
    public let generateCommand: GeneratePRDCommand?
    public let answers: [String]?
    public let result: PRDDocumentDTO?
    public let section: SectionUpdateDTO?

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
        section: SectionUpdateDTO? = nil,
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


