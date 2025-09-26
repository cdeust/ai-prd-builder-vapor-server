import Foundation
import Vapor
import Domain

/// Interactive message for WebSocket communication
public struct InteractiveMessage: Content {
    public let type: String
    public let questions: [String]?
    public let generateCommand: GeneratePRDCommand?
    public let answers: [String]?
    public let result: PRDDocumentDTO?

    public init(
        type: String,
        questions: [String]? = nil,
        generateCommand: GeneratePRDCommand? = nil,
        answers: [String]? = nil,
        result: PRDDocumentDTO? = nil
    ) {
        self.type = type
        self.questions = questions
        self.generateCommand = generateCommand
        self.answers = answers
        self.result = result
    }
}