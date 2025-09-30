import Foundation
import Vapor

public struct AnalysisJobResponseDTO: Content {
    let requestId: String
    let status: String
    let message: String
}
