import Foundation

struct OpenAICostCalculator {
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
        if model.contains("gpt-4o") {
            return (2.50, 10.00)
        } else if model.contains("gpt-4-turbo") {
            return (10.00, 30.00)
        } else if model.contains("gpt-4") {
            return (30.00, 60.00)
        } else if model.contains("gpt-3.5-turbo") {
            return (0.50, 1.50)
        } else {
            return (2.50, 10.00)
        }
    }
}