import Foundation
import Observation
import FoundationModels

@MainActor
@Observable
final class SetupViewModel {
    var isComplete = false
    var unavailableReason: String?

    var modelAvailability: SystemLanguageModel.Availability {
        SystemLanguageModel.default.availability
    }

    var isModelAvailable: Bool {
        modelAvailability == .available
    }

    func completeOnboarding() {
        isComplete = true
    }

    // If the model is already available, skip straight through.
    @discardableResult
    func skipIfAvailable() -> Bool {
        guard isModelAvailable else { return false }
        isComplete = true
        return true
    }
}
