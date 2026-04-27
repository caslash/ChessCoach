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

    // Available means the model is ready AND supports a usable locale.
    // FoundationModels requires the system language to be one it supports;
    // we fall back to checking English explicitly so coaching works for
    // English-prompt apps regardless of the system display language.
    nonisolated var isAvailable: Bool {
        guard availability == .available else { return false }
        let model = SystemLanguageModel.default
        // Prefer current locale; fall back to en_US for English coaching prompts.
        return model.supportsLocale(.current) || model.supportsLocale(Locale(identifier: "en_US"))
    }

    nonisolated var unavailabilityMessage: String? {
        guard availability == .available else {
            guard case .unavailable(let reason) = availability else { return nil }
            switch reason {
            case .appleIntelligenceNotEnabled:
                return "Enable Apple Intelligence in System Settings → Apple Intelligence & Siri."
            case .modelNotReady:
                return "Apple Intelligence model is downloading. Coaching will be available shortly."
            case .deviceNotEligible:
                return "This Mac does not support Apple Intelligence. Coaching is unavailable."
            @unknown default:
                return "Apple Intelligence is unavailable."
            }
        }
        // Model is available but locale isn't supported
        let model = SystemLanguageModel.default
        if !model.supportsLocale(.current) && !model.supportsLocale(Locale(identifier: "en_US")) {
            return "Coaching requires English system language. Go to System Settings → Language & Region and add English."
        }
        return nil
    }

    // MARK: - Streaming

    // Creates a fresh LanguageModelSession per call (stateless — no cross-message context).
    // Forces en_US locale instructions when the system locale isn't directly supported.
    func streamCoaching(systemPrompt: String, userPrompt: String) -> AsyncThrowingStream<String, any Error> {
        let (stream, continuation) = AsyncThrowingStream<String, any Error>.makeStream()
        Task {
            await runCoachingStream(
                systemPrompt: systemPrompt,
                userPrompt: userPrompt,
                continuation: continuation,
                attemptsRemaining: 2
            )
        }
        return stream
    }

    private func runCoachingStream(
        systemPrompt: String,
        userPrompt: String,
        continuation: AsyncThrowingStream<String, any Error>.Continuation,
        attemptsRemaining: Int
    ) async {
        log.info("Starting coaching stream (locale: \(Locale.current.identifier), attempts left: \(attemptsRemaining))")
        do {
            let session = LanguageModelSession(instructions: systemPrompt)
            let responseStream = session.streamResponse(to: userPrompt)
            var accumulated = ""
            for try await snapshot in responseStream {
                let full = snapshot.content
                let delta = String(full.dropFirst(accumulated.count))
                accumulated = full
                if !delta.isEmpty { continuation.yield(delta) }
            }
            log.info("Coaching stream finished (\(accumulated.count) chars)")
            continuation.finish()
        } catch let error as LanguageModelSession.GenerationError {
            log.error("Generation error: \(error)")
            switch error {
            case .unsupportedLanguageOrLocale:
                // Can be intermittent in macOS 26 — retry once before surfacing the error
                if attemptsRemaining > 1 {
                    log.warning("unsupportedLanguageOrLocale — retrying in 1 s")
                    try? await Task.sleep(for: .seconds(1))
                    await runCoachingStream(
                        systemPrompt: systemPrompt,
                        userPrompt: userPrompt,
                        continuation: continuation,
                        attemptsRemaining: attemptsRemaining - 1
                    )
                } else {
                    continuation.finish(throwing: LLMManagerError.unsupportedLocale)
                }
            case .guardrailViolation:
                continuation.finish()
            case .assetsUnavailable:
                continuation.finish(throwing: LLMManagerError.modelNotReady)
            case .rateLimited, .concurrentRequests:
                if attemptsRemaining > 1 {
                    try? await Task.sleep(for: .seconds(2))
                    await runCoachingStream(
                        systemPrompt: systemPrompt,
                        userPrompt: userPrompt,
                        continuation: continuation,
                        attemptsRemaining: attemptsRemaining - 1
                    )
                } else {
                    continuation.finish(throwing: error)
                }
            default:
                continuation.finish(throwing: error)
            }
        } catch {
            log.error("Coaching stream error: \(error)")
            continuation.finish(throwing: error)
        }
    }
}

// MARK: - Errors

enum LLMManagerError: LocalizedError {
    case unsupportedLocale
    case modelNotReady

    var errorDescription: String? {
        switch self {
        case .unsupportedLocale:
            return "Coaching requires English system language. Go to System Settings → Language & Region and add English as a preferred language."
        case .modelNotReady:
            return "Apple Intelligence model is not ready yet. Try again in a moment."
        }
    }
}
