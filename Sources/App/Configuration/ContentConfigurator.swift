import Vapor

/// Handles content encoding/decoding configuration for the application
public final class ContentConfigurator {
    private let app: Application

    public init(app: Application) {
        self.app = app
    }

    /// Configure JSON encoding and decoding
    public func configure() {
        let encoder = createJSONEncoder()
        let decoder = createJSONDecoder()

        ContentConfiguration.global.use(encoder: encoder, for: .json)
        ContentConfiguration.global.use(decoder: decoder, for: .json)
    }

    // MARK: - Private Methods

    private func createJSONEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.keyEncodingStrategy = .convertToSnakeCase
        return encoder
    }

    private func createJSONDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }
}