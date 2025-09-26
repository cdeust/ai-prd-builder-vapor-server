import Foundation

struct GeminiCostCalculator {
    func calculateCost(tokensUsed: Int?, model: String) -> Double? {
        guard let tokens = tokensUsed else { return nil }

        let (inputCostPer1M, outputCostPer1M) = getCostPerMillion(for: model)

        let inputTokens = Double(tokens) * 0.7
        let outputTokens = Double(tokens) * 0.3

        let inputCost = (inputTokens / 1_000_000.0) * inputCostPer1M
        let outputCost = (outputTokens / 1_000_000.0) * outputCostPer1M

        return inputCost + outputCost
    }

    private func getCostPerMillion(for model: String) -> (input: Double, output: Double) {
        if model.contains("gemini-2.0-flash") {
            return (0.10, 0.40)
        } else if model.contains("gemini-1.5-pro") {
            return (1.25, 5.00)
        } else if model.contains("gemini-1.5-flash") {
            return (0.075, 0.30)
        } else {
            return (0.10, 0.40)
        }
    }
}