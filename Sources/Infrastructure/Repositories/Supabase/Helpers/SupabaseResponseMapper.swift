import Foundation
import Domain

struct SupabaseResponseMapper {
    static func mapSingleResult<T: Decodable>(_ models: [T]) throws -> T {
        guard let model = models.first else {
            throw DomainError.processingFailed("No data returned from Supabase operation")
        }
        return model
    }

    static func mapOptionalResult<T: Decodable>(_ models: [T]) -> T? {
        return models.first
    }
}