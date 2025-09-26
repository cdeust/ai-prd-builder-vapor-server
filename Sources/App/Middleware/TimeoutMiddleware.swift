import Vapor

public struct TimeoutMiddleware: AsyncMiddleware {
    let timeoutSeconds: Int

    public init(timeoutSeconds: Int = 30) {
        self.timeoutSeconds = timeoutSeconds
    }

    public func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
        let task = Task {
            try await next.respond(to: request)
        }

        let timeoutTask = Task {
            try await Task.sleep(for: .seconds(timeoutSeconds))
            task.cancel()
        }

        do {
            let response = try await task.value
            timeoutTask.cancel()
            return response
        } catch is CancellationError {
            throw Abort(.requestTimeout, reason: "Request timeout after \(timeoutSeconds) seconds")
        } catch {
            timeoutTask.cancel()
            throw error
        }
    }
}