import Vapor
import Domain
import Application
import ImplementationAnalysis

/// Diagnostic controller to verify database connectivity and data flow
public final class DiagnosticsController: RouteCollection, @unchecked Sendable {
    private let prdRepository: PRDRepositoryProtocol
    private let documentRepository: PRDDocumentRepositoryProtocol
    private let mockupUploadRepository: MockupUploadRepositoryProtocol
    private let codebaseRepository: CodebaseRepositoryProtocol

    public init(
        prdRepository: PRDRepositoryProtocol,
        documentRepository: PRDDocumentRepositoryProtocol,
        mockupUploadRepository: MockupUploadRepositoryProtocol,
        codebaseRepository: CodebaseRepositoryProtocol
    ) {
        self.prdRepository = prdRepository
        self.documentRepository = documentRepository
        self.mockupUploadRepository = mockupUploadRepository
        self.codebaseRepository = codebaseRepository
    }

    public func boot(routes: RoutesBuilder) throws {
        let diagnostics = routes.grouped("api", "v1", "diagnostics")

        diagnostics.get("health", use: healthCheck)
        diagnostics.get("database", use: databaseCheck)
        diagnostics.post("test-flow", use: testDataFlow)
    }

    /// GET /api/v1/diagnostics/health
    /// Basic health check
    func healthCheck(req: Request) async throws -> DiagnosticsHealthDTO {
        return DiagnosticsHealthDTO(
            status: "healthy",
            timestamp: Date(),
            version: Environment.get("APP_VERSION") ?? "unknown",
            database: Environment.get("DATABASE_TYPE") ?? "unknown"
        )
    }

    /// GET /api/v1/diagnostics/database
    /// Check database tables and counts
    func databaseCheck(req: Request) async throws -> DatabaseDiagnosticsDTO {
        var prdRequestCount = 0
        var prdDocumentCount = 0
        var mockupUploadCount = 0
        var codebaseProjectCount = 0
        var errors: [String] = []

        // Check PRD requests
        do {
            // Note: findAll() not implemented in protocol, using placeholder
            prdRequestCount = 0 // TODO: Implement findAll() in PRDRepositoryProtocol
        } catch {
            errors.append("PRD Requests: \(error.localizedDescription)")
        }

        // Check PRD documents
        do {
            // Try to get all documents (may not have this method)
            prdDocumentCount = 0 // Would need to implement findAll() in repository
        } catch {
            errors.append("PRD Documents: \(error.localizedDescription)")
        }

        // Check mockup uploads
        do {
            // Create a test request to query
            let testRequestId = UUID()
            let mockups = try? await mockupUploadRepository.findByRequestId(testRequestId)
            mockupUploadCount = mockups?.count ?? 0
        } catch {
            errors.append("Mockup Uploads: \(error.localizedDescription)")
        }

        // Check codebase projects
        do {
            // Note: listAllProjects() not implemented in protocol, using placeholder
            codebaseProjectCount = 0 // TODO: Implement listAllProjects() in CodebaseRepositoryProtocol
        } catch {
            errors.append("Codebase Projects: \(error.localizedDescription)")
        }

        return DatabaseDiagnosticsDTO(
            prdRequests: prdRequestCount,
            prdDocuments: prdDocumentCount,
            mockupUploads: mockupUploadCount,
            codebaseProjects: codebaseProjectCount,
            errors: errors,
            supabaseUrl: Environment.get("SUPABASE_URL") ?? "not set",
            hasServiceRoleKey: Environment.get("SUPABASE_SERVICE_ROLE_KEY") != nil,
            hasAnonKey: Environment.get("SUPABASE_ANON_KEY") != nil
        )
    }

    /// POST /api/v1/diagnostics/test-flow
    /// Test the complete data flow: PRD request → mockup upload → codebase linking
    func testDataFlow(req: Request) async throws -> DataFlowTestDTO {
        var steps: [TestStepDTO] = []

        // Step 1: Create test PRD request
        do {
            let testRequest = PRDRequest(
                title: "Test PRD - Diagnostics",
                description: "This is a test PRD request created by the diagnostics endpoint",
                priority: .medium,
                requester: Requester(id: "diagnostics", email: "diagnostics@test.com")
            )

            let savedRequest = try await prdRepository.save(testRequest)
            steps.append(TestStepDTO(
                step: "Create PRD Request",
                status: "success",
                message: "Created request with ID: \(savedRequest.id)",
                data: ["id": savedRequest.id.uuidString]
            ))

            // Step 2: Create test mockup upload (without actual file)
            do {
                let testMockup = MockupUpload(
                    prdRequestId: savedRequest.id,
                    storagePath: "test/diagnostics/test-mockup.png",
                    fileName: "test-mockup.png",
                    fileSize: 1024,
                    mimeType: "image/png"
                )

                let savedMockup = try await mockupUploadRepository.save(testMockup)
                steps.append(TestStepDTO(
                    step: "Create Mockup Upload",
                    status: "success",
                    message: "Created mockup upload with ID: \(savedMockup.id)",
                    data: ["id": savedMockup.id.uuidString]
                ))

                // Step 3: Update mockup with fake analysis
                do {
                    let fakeAnalysis = MockupAnalysisResult(
                        uiElements: [
                            UIElement(
                                type: .button,
                                label: "Test Button",
                                bounds: ElementBounds(x: 0, y: 0, width: 100, height: 50),
                                confidence: 0.95
                            )
                        ],
                        layoutStructure: LayoutStructure(
                            screenType: .other,
                            hierarchyLevels: 1,
                            primaryLayout: .vertical,
                            componentGroups: []
                        ),
                        extractedText: [
                            ExtractedText(
                                text: "Test Text",
                                category: .label,
                                bounds: ElementBounds(x: 0, y: 0, width: 100, height: 20)
                            )
                        ],
                        inferredUserFlows: [
                            UserFlow(flowName: "Test Flow", steps: ["Step 1", "Step 2"], confidence: 0.85)
                        ],
                        businessLogicInferences: [
                            BusinessLogicInference(
                                feature: "Test Feature",
                                description: "Test business logic",
                                confidence: 0.9,
                                requiredComponents: ["Component A"]
                            )
                        ]
                    )

                    let analyzedMockup = savedMockup.withAnalysis(result: fakeAnalysis, confidence: 0.9)
                    let updatedMockup = try await mockupUploadRepository.update(analyzedMockup)

                    steps.append(TestStepDTO(
                        step: "Update Mockup Analysis",
                        status: "success",
                        message: "Updated mockup with analysis result",
                        data: ["hasAnalysis": String(updatedMockup.analysisResult != nil)]
                    ))

                } catch {
                    steps.append(TestStepDTO(
                        step: "Update Mockup Analysis",
                        status: "failed",
                        message: "Failed to update mockup: \(error.localizedDescription)",
                        data: nil
                    ))
                }

            } catch {
                steps.append(TestStepDTO(
                    step: "Create Mockup Upload",
                    status: "failed",
                    message: "Failed to create mockup: \(error.localizedDescription)",
                    data: nil
                ))
            }

            // Step 4: Create test codebase project
            do {
                let testCodebase = CodebaseProject(
                    repositoryUrl: "https://github.com/test/diagnostics",
                    repositoryBranch: "main",
                    repositoryType: .github
                )

                let savedCodebase = try await codebaseRepository.saveProject(testCodebase)
                steps.append(TestStepDTO(
                    step: "Create Codebase Project",
                    status: "success",
                    message: "Created codebase with ID: \(savedCodebase.id)",
                    data: ["id": savedCodebase.id.uuidString]
                ))

            } catch {
                steps.append(TestStepDTO(
                    step: "Create Codebase Project",
                    status: "failed",
                    message: "Failed to create codebase: \(error.localizedDescription)",
                    data: nil
                ))
            }

        } catch {
            steps.append(TestStepDTO(
                step: "Create PRD Request",
                status: "failed",
                message: "Failed to create PRD request: \(error.localizedDescription)",
                data: nil
            ))
        }

        let successCount = steps.filter { $0.status == "success" }.count
        let totalSteps = steps.count

        return DataFlowTestDTO(
            success: successCount == totalSteps,
            totalSteps: totalSteps,
            successfulSteps: successCount,
            failedSteps: totalSteps - successCount,
            steps: steps,
            timestamp: Date()
        )
    }
}

// MARK: - DTOs

public struct DiagnosticsHealthDTO: Content {
    let status: String
    let timestamp: Date
    let version: String
    let database: String
}

public struct DatabaseDiagnosticsDTO: Content {
    let prdRequests: Int
    let prdDocuments: Int
    let mockupUploads: Int
    let codebaseProjects: Int
    let errors: [String]
    let supabaseUrl: String
    let hasServiceRoleKey: Bool
    let hasAnonKey: Bool
}

public struct DataFlowTestDTO: Content {
    let success: Bool
    let totalSteps: Int
    let successfulSteps: Int
    let failedSteps: Int
    let steps: [TestStepDTO]
    let timestamp: Date
}

public struct TestStepDTO: Content {
    let step: String
    let status: String
    let message: String
    let data: [String: String]?
}
