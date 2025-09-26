import Foundation

/// Domain entity representing a PRD generation request
/// This is a pure domain object with no framework dependencies
public struct PRDRequest {
    public let id: UUID
    public let title: String
    public let description: String
    public let mockupSources: [MockupSource]
    public let priority: Priority
    public let requester: Requester
    public let metadata: RequestMetadata
    public let createdAt: Date
    public let status: RequestStatus

    public init(
        id: UUID = UUID(),
        title: String,
        description: String,
        mockupSources: [MockupSource] = [],
        priority: Priority = .medium,
        requester: Requester,
        metadata: RequestMetadata = RequestMetadata(),
        createdAt: Date = Date(),
        status: RequestStatus = .pending
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.mockupSources = mockupSources
        self.priority = priority
        self.requester = requester
        self.metadata = metadata
        self.createdAt = createdAt
        self.status = status
    }
}

// MARK: - Supporting Types

public struct Requester {
    public let id: String
    public let email: String?
    public let organizationId: String?

    public init(id: String, email: String? = nil, organizationId: String? = nil) {
        self.id = id
        self.email = email
        self.organizationId = organizationId
    }
}

public struct RequestMetadata {
    public let tags: [String]
    public let projectId: String?
    public let version: String?
    public let customFields: [String: String]

    public init(
        tags: [String] = [],
        projectId: String? = nil,
        version: String? = nil,
        customFields: [String: String] = [:]
    ) {
        self.tags = tags
        self.projectId = projectId
        self.version = version
        self.customFields = customFields
    }
}

public enum RequestStatus: Equatable {
    case pending
    case processing
    case clarificationNeeded
    case completed
    case failed(reason: String)
    case cancelled

    public var rawValue: String {
        switch self {
        case .pending: return "pending"
        case .processing: return "processing"
        case .clarificationNeeded: return "clarificationNeeded"
        case .completed: return "completed"
        case .failed: return "failed"
        case .cancelled: return "cancelled"
        }
    }

    public static func from(rawValue: String) -> RequestStatus {
        switch rawValue {
        case "pending": return .pending
        case "processing": return .processing
        case "clarificationNeeded": return .clarificationNeeded
        case "completed": return .completed
        case "failed": return .failed(reason: "")
        case "cancelled": return .cancelled
        default: return .pending
        }
    }
}

// MARK: - Domain Logic

extension PRDRequest {
    /// Business rule: High priority requests must have a description
    public func validate() throws {
        guard !title.isEmpty else {
            throw DomainError.validation("Title is required")
        }

        if priority == .critical && description.count < 50 {
            throw DomainError.validation("Critical priority requests require detailed description (min 50 characters)")
        }

        if mockupSources.count > 20 {
            throw DomainError.validation("Maximum 20 mockups allowed per request")
        }
    }

    /// Check if request can be processed
    public var canProcess: Bool {
        switch status {
        case .pending, .clarificationNeeded:
            return true
        default:
            return false
        }
    }

    /// Update status with validation
    public func withStatus(_ newStatus: RequestStatus) -> PRDRequest {
        PRDRequest(
            id: id,
            title: title,
            description: description,
            mockupSources: mockupSources,
            priority: priority,
            requester: requester,
            metadata: metadata,
            createdAt: createdAt,
            status: newStatus
        )
    }
}