import Vapor
import Domain
import Application

public final class PRDManagementController: RouteCollection, @unchecked Sendable {
    private let applicationService: PRDApplicationService

    public init(applicationService: PRDApplicationService) {
        self.applicationService = applicationService
    }

    public func boot(routes: RoutesBuilder) throws {
        let prd = routes.grouped("api", "v1", "prd")

        prd.get(":requestId", "status", use: getStatus)
        prd.get("requests", use: listRequests)
        prd.get("documents", ":documentId", "export", use: exportDocument)
    }

    func getStatus(req: Request) async throws -> GenerationStatusResponseDTO {
        guard let requestIdString = req.parameters.get("requestId"),
              let requestId = UUID(uuidString: requestIdString) else {
            throw Abort(.badRequest, reason: "Invalid request ID")
        }

        let status = try await applicationService.getGenerationStatus(requestId: requestId)

        return GenerationStatusResponseDTO(
            requestId: status.requestId,
            status: status.status.rawValue,
            progress: status.progress,
            document: status.document.map(PRDDocumentDTO.from),
            createdAt: status.createdAt,
            updatedAt: status.updatedAt,
            completedAt: status.completedAt
        )
    }

    func listRequests(req: Request) async throws -> PRDRequestListResponseDTO {
        let userId = "current-user"
        let limit = req.query["limit"] ?? 20
        let offset = req.query["offset"] ?? 0

        let requests = try await applicationService.listPRDRequests(
            for: userId,
            limit: limit,
            offset: offset
        )

        return PRDRequestListResponseDTO(
            requests: requests.map { PRDRequestSummaryDTO(
                id: $0.id,
                title: $0.title,
                status: $0.status.rawValue,
                priority: $0.priority.rawValue,
                createdAt: $0.createdAt,
                completedAt: nil
            ) },
            pagination: PaginationDTO(
                limit: limit,
                offset: offset,
                total: requests.count
            )
        )
    }

    func exportDocument(req: Request) async throws -> Response {
        guard let documentIdString = req.parameters.get("documentId"),
              let documentId = UUID(uuidString: documentIdString) else {
            throw Abort(.badRequest, reason: "Invalid document ID")
        }

        let formatString = req.query["format"] ?? "markdown"
        guard let format = DocumentFormat(rawValue: formatString) else {
            throw Abort(.badRequest, reason: "Invalid export format")
        }

        let exportResult = try await applicationService.exportPRD(
            documentId: documentId,
            format: format
        )

        let response = Response()
        response.body = .init(string: exportResult.content)
        response.headers.contentType = HTTPMediaType(type: exportResult.mimeType.components(separatedBy: "/")[0],
                                                     subType: exportResult.mimeType.components(separatedBy: "/")[1])
        response.headers.add(name: "Content-Disposition", value: "attachment; filename=\"\(exportResult.filename)\"")

        return response
    }
}