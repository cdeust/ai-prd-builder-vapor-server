import Foundation

/// Configuration errors for dependency injection
public enum ConfigurationError: Error, LocalizedError {
    case missingAIProvider
    case missingDependency(String)
    case missingEnvironmentVariable(String)
    case invalidConfiguration(String)

    public var errorDescription: String? {
        switch self {
        case .missingAIProvider:
            return "No AI providers are configured. Please set at least one API key (ANTHROPIC_API_KEY, OPENAI_API_KEY, or GEMINI_API_KEY)."
        case .missingDependency(let dependency):
            return "Missing required dependency: \(dependency)"
        case .missingEnvironmentVariable(let variable):
            return "Missing required environment variable: \(variable)"
        case .invalidConfiguration(let details):
            return "Invalid configuration: \(details)"
        }
    }
}