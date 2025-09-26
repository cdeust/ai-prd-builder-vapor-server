import Foundation

struct ProviderCapabilitiesMapper {
    func getCapabilities(for providerName: String) -> [String] {
        switch providerName.lowercased() {
        case "apple", "mlx":
            return ["On-device processing", "Privacy-first", "Fast inference", "PRD generation"]
        case "anthropic":
            return ["Advanced reasoning", "Long context", "PRD generation", "Code analysis"]
        case "openai":
            return ["GPT-4 capabilities", "Function calling", "PRD generation", "Image analysis"]
        case "gemini":
            return ["Multi-modal", "Long context", "PRD generation", "Cost-effective"]
        default:
            return ["PRD generation"]
        }
    }
}