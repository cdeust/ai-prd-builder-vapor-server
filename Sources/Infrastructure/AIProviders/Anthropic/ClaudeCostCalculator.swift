import Foundation

struct ClaudeCostCalculator {
    func calculateCost(tokensUsed: Int?) -> Double? {
        guard let tokens = tokensUsed else { return nil }

        let inputCostPer1K = 0.003
        let outputCostPer1K = 0.015

        let inputTokens = Double(tokens) * 0.7
        let outputTokens = Double(tokens) * 0.3

        let inputCost = (inputTokens / 1000.0) * inputCostPer1K
        let outputCost = (outputTokens / 1000.0) * outputCostPer1K

        return inputCost + outputCost
    }
}