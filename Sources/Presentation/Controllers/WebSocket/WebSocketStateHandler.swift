import Foundation

actor WebSocketStateHandler {
    var clarificationResolver: CheckedContinuation<[String], Never>?

    func setClarificationResolver(_ resolver: CheckedContinuation<[String], Never>) {
        self.clarificationResolver = resolver
    }

    func getClarificationResolver() -> CheckedContinuation<[String], Never>? {
        return clarificationResolver
    }

    func clearClarificationResolver() {
        self.clarificationResolver = nil
    }
}