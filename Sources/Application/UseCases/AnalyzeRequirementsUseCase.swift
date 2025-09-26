import Foundation
import Domain

/// Use case for analyzing requirements and collecting clarifications
/// Implements the intelligent clarification system from the Swift CLI version
public final class AnalyzeRequirementsUseCase {
    private let aiProvider: AIProviderPort

    public init(aiProvider: AIProviderPort) {
        self.aiProvider = aiProvider
    }

    /// Analyze user requirements and determine clarifications needed
    public func execute(_ description: String, mockupSources: [MockupSource] = []) async throws -> RequirementsAnalysis {
        // 1. Analyze text requirements
        let textAnalysis = try await aiProvider.analyzeRequirements(description)

        // 2. If mockups provided, extract additional context
        var mockupAnalysis: MockupAnalysis?
        if !mockupSources.isEmpty {
            mockupAnalysis = try await aiProvider.extractFromMockups(mockupSources)
        }

        // 3. Combine analyses and determine overall confidence
        let combinedConfidence = calculateCombinedConfidence(
            textAnalysis: textAnalysis,
            mockupAnalysis: mockupAnalysis
        )

        // 4. Generate comprehensive clarifications
        let comprehensiveClarifications = generateComprehensiveClarifications(
            textAnalysis: textAnalysis,
            mockupAnalysis: mockupAnalysis
        )

        return RequirementsAnalysis(
            confidence: combinedConfidence,
            clarificationsNeeded: comprehensiveClarifications,
            assumptions: combineAssumptions(textAnalysis, mockupAnalysis),
            gaps: combineGaps(textAnalysis, mockupAnalysis)
        )
    }

    // MARK: - Private Helper Methods

    /// Calculate overall confidence combining text and mockup analysis
    private func calculateCombinedConfidence(
        textAnalysis: RequirementsAnalysis,
        mockupAnalysis: MockupAnalysis?
    ) -> Double {
        var confidence = textAnalysis.confidence

        // Mockup analysis can boost confidence
        if let mockupAnalysis = mockupAnalysis {
            let mockupBonus = calculateMockupBonus(mockupAnalysis)
            confidence = min(1.0, confidence + mockupBonus)
        }

        return confidence
    }

    /// Calculate confidence bonus from mockup analysis
    private func calculateMockupBonus(_ mockupAnalysis: MockupAnalysis) -> Double {
        var bonus: Double = 0

        // More extracted features = higher confidence (max 0.15 boost)
        if !mockupAnalysis.extractedFeatures.isEmpty {
            let featureBonus = Double(min(15, mockupAnalysis.extractedFeatures.count * 3)) / 100.0
            bonus += featureBonus
        }

        // Clear user flows boost confidence (max 0.10 boost)
        if !mockupAnalysis.userFlows.isEmpty {
            let flowBonus = Double(min(10, mockupAnalysis.userFlows.count * 2)) / 100.0
            bonus += flowBonus
        }

        // UI components provide implementation clarity (max 0.10 boost)
        if !mockupAnalysis.uiComponents.isEmpty {
            let componentBonus = Double(min(10, mockupAnalysis.uiComponents.count * 1)) / 100.0
            bonus += componentBonus
        }

        return bonus
    }

    /// Generate comprehensive clarifications from all available analysis
    private func generateComprehensiveClarifications(
        textAnalysis: RequirementsAnalysis,
        mockupAnalysis: MockupAnalysis?
    ) -> [String] {
        var clarifications = textAnalysis.clarificationsNeeded

        // Add mockup-specific clarifications
        if let mockupAnalysis = mockupAnalysis {
            clarifications.append(contentsOf: generateMockupClarifications(mockupAnalysis))
        }

        // Remove duplicates and sort by priority
        return Array(Set(clarifications)).sorted { lhs, rhs in
            priorityScore(for: lhs) > priorityScore(for: rhs)
        }
    }

    /// Generate clarifications based on mockup analysis
    private func generateMockupClarifications(_ mockupAnalysis: MockupAnalysis) -> [String] {
        var clarifications: [String] = []

        // Check for missing business logic clarifications
        if mockupAnalysis.businessLogic.isEmpty && !mockupAnalysis.extractedFeatures.isEmpty {
            clarifications.append("How should the business logic work for the identified features: \(mockupAnalysis.extractedFeatures.joined(separator: ", "))?")
        }

        // Check for incomplete user flows
        if mockupAnalysis.userFlows.count < mockupAnalysis.extractedFeatures.count {
            clarifications.append("Can you provide complete user flows for all features shown in the mockups?")
        }

        // Check for data requirements
        if !mockupAnalysis.uiComponents.contains(where: { $0.lowercased().contains("form") || $0.lowercased().contains("input") }) {
            clarifications.append("What data needs to be collected or displayed that might not be visible in the mockups?")
        }

        return clarifications
    }

    /// Assign priority score to clarifications for sorting
    private func priorityScore(for clarification: String) -> Int {
        let lowercased = clarification.lowercased()

        // High priority: business logic, data, security
        if lowercased.contains("business logic") || lowercased.contains("data") || lowercased.contains("security") {
            return 10
        }

        // Medium priority: user flows, requirements
        if lowercased.contains("user flow") || lowercased.contains("requirement") {
            return 5
        }

        // Low priority: UI details
        return 1
    }

    /// Combine assumptions from multiple analyses
    private func combineAssumptions(
        _ textAnalysis: RequirementsAnalysis,
        _ mockupAnalysis: MockupAnalysis?
    ) -> [String] {
        var assumptions = textAnalysis.assumptions

        // Add mockup-derived assumptions
        if let mockupAnalysis = mockupAnalysis {
            if !mockupAnalysis.userFlows.isEmpty {
                assumptions.append("User flows will follow the patterns shown in mockups")
            }
            if !mockupAnalysis.uiComponents.isEmpty {
                assumptions.append("UI components will match the mockup designs")
            }
        }

        return Array(Set(assumptions))
    }

    /// Combine gaps from multiple analyses
    private func combineGaps(
        _ textAnalysis: RequirementsAnalysis,
        _ mockupAnalysis: MockupAnalysis?
    ) -> [String] {
        var gaps = textAnalysis.gaps

        // Add mockup-specific gaps
        if let mockupAnalysis = mockupAnalysis,
           mockupAnalysis.businessLogic.isEmpty && !mockupAnalysis.extractedFeatures.isEmpty {
            gaps.append("Business logic details for mockup features")
        }

        return Array(Set(gaps))
    }
}