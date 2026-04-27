import Foundation
import FoundationModels

// Uses Apple Intelligence (FoundationModels) for on-device coaching inference.
// No model download required — the system model is part of macOS 26.
actor LLMManager {
    static let shared = LLMManager()
    private init() {}

    // MARK: - Availability

    // Check on MainActor before calling streamCoaching.
    nonisolated var isAvailable: Bool {
        SystemLanguageModel.default.availability == .available
    }

    // MARK: - Streaming

    // Returns incremental text tokens for one coaching response.
    // Creates a fresh session per call so each message is stateless.
    func streamCoaching(systemPrompt: String, userPrompt: String) -> AsyncThrowingStream<String, any Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let session = LanguageModelSession(instructions: systemPrompt)
                    let stream = session.streamResponse(to: userPrompt)
                    var accumulated = ""
                    for try await snapshot in stream {
                        let full = snapshot.content
                        let delta = String(full.dropFirst(accumulated.count))
                        accumulated = full
                        if !delta.isEmpty { continuation.yield(delta) }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}

enum LLMManagerError: LocalizedError {
    case unavailable

    var errorDescription: String? {
        "Apple Intelligence is not available on this device. Enable it in System Settings → Apple Intelligence & Siri."
    }
}
