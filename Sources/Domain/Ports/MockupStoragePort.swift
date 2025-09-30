import Foundation

public protocol MockupStoragePort: Sendable {
    /// Upload mockup image to storage
    /// - Parameters:
    ///   - data: Image file data
    ///   - fileName: Original file name
    ///   - requestId: Associated PRD request ID
    ///   - mimeType: MIME type of the image
    /// - Returns: Storage path where the file was saved
    func upload(
        data: Data,
        fileName: String,
        requestId: UUID,
        mimeType: String
    ) async throws -> String

    /// Download mockup image from storage
    /// - Parameter path: Storage path
    /// - Returns: Image file data
    func download(path: String) async throws -> Data

    /// Delete mockup image from storage
    /// - Parameter path: Storage path
    func delete(path: String) async throws

    /// Generate a signed URL for temporary access
    /// - Parameters:
    ///   - path: Storage path
    ///   - expiresIn: Duration in seconds for URL validity
    /// - Returns: Signed URL string
    func generateSignedURL(path: String, expiresIn: Int) async throws -> String

    /// Delete all mockups for a specific request
    /// - Parameter requestId: PRD request ID
    func deleteAllForRequest(requestId: UUID) async throws

    /// Check if a file exists in storage
    /// - Parameter path: Storage path
    /// - Returns: True if file exists
    func exists(path: String) async throws -> Bool
}