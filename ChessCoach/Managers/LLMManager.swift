import Foundation
import FoundationModels
import OSLog

private let log = Logger(subsystem: "com.chesscoach", category: "LLMManager")

// Uses Apple Intelligence (FoundationModels) for on-device coaching inference.
// No model download required — the system model is part of macOS 26.
actor LLMManager {
    static let shared = LLMManager()
    private init() {}

    // MARK: - Availability

    nonisolated var availability: SystemLanguageModel.Availability {
        SystemLanguageModel.default.availability
    }

    nonisolated var isAvailable: Bool {
        availability == .available
    }

    // Human-readable explanation for why the model is unavailable.
    nonisolated var unavailabilityMessage: String? {
        guard case .unavailable(let reason) = availability else { return nil }
        switch reason {
        case .appleIntelligenceNotEnabled:
            return "Enable Apple Intelligence in System Settings → Apple Intelligence & Siri to activate coaching."
        case .modelNotReady:
            return "Apple Intelligence model is downloading. Coaching will be available shortly."
        case .deviceNotEligible:
            return "This Mac does not support Apple Intelligence. Coaching is unavailable."
        @unknown default:
            return "Apple Intelligence is unavailable."
        }
    }

    // MARK: - Streaming

    // Returns incremental text tokens for one coaching response.
    // Creates a fresh LanguageModelSession per call (stateless — no cross-message context).
    func streamCoaching(systemPrompt: String, userPrompt: String) -> AsyncThrowingStream<String, any Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    log.info("Starting coaching stream")
                    let session = LanguageModelSession(instructions: systemPrompt)
                    let stream = session.streamResponse(to: userPrompt)
                    var accumulated = ""
                    for try await snapshot in stream {
                        let full = snapshot.content
                        let delta = String(full.dropFirst(accumulated.count))
                        accumulated = full
                        if !delta.isEmpty { continuation.yield(delta) }
                    }
                    log.info("Coaching stream finished (\(accumulated.count) chars)")
                    continuation.finish()
                } catch {
                    log.error("Coaching stream error: \(error)")
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}
