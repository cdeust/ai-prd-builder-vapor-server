import Vapor

// MARK: - Vapor Service Extensions

extension Application {
    private struct DIContainerKey: StorageKey {
        typealias Value = DIContainer
    }

    public var diContainer: DIContainer {
        get {
            guard let container = storage[DIContainerKey.self] else {
                let container = DIContainer(app: self)
                storage[DIContainerKey.self] = container
                return container
            }
            return container
        }
        set {
            storage[DIContainerKey.self] = newValue
        }
    }
}

extension Request {
    /// Resolve service from DI container
    public func resolve<T>(_ type: T.Type) -> T? {
        return application.diContainer.resolve(type)
    }
}