import Vapor
import Domain
import Presentation

public final class DomainErrorMiddleware: AsyncMiddleware {
    public init() {}

    public func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
        do {
            return try await next.respond(to: request)
        } catch let error as DomainError {
            let status: HTTPStatus
            let message: String

            switch error {
            case .validation(let msg):
                status = .badRequest
                message = msg
            case .notFound(let msg):
                status = .notFound
                message = msg
            case .businessRule(let msg):
                status = .unprocessableEntity
                message = msg
            case .conflict(let msg):
                status = .conflict
                message = msg
            case .unauthorized(let msg):
                status = .unauthorized
                message = msg
            case .processingFailed(let msg):
                status = .internalServerError
                message = msg
            }

            let errorResponse = ErrorResponseDTO(
                error: ErrorDetailDTO(
                    code: String(describing: error).components(separatedBy: "(")[0],
                    message: message,
                    timestamp: Date()
                )
            )

            let response = Response(status: status)
            try response.content.encode(errorResponse)
            return response
        }
    }
}