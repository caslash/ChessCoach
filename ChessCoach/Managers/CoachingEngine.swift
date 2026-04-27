import Foundation
import OSLog

private let log = Logger(subsystem: "com.chesscoach", category: "CoachingEngine")

// Evaluates move quality by comparing Stockfish centipawn scores before and after a move,
// then classifies and decides whether to trigger coaching. @MainActor so it can await the
// Stockfish actor and mutate GameViewModel state on the same executor.
@MainActor
final class CoachingEngine {
    static let shared = CoachingEngine()
    private init() {}

    // MARK: - Types

    /// Controls which moves trigger coaching.
    enum Verbosity: String {
        case quiet   = "quiet"    // blunders only (200+)
        case normal  = "normal"   // mistakes + blunders (100+)   ← default
        case verbose = "verbose"  // inaccuracies and above (50+)

        var playerThreshold: Int {
            switch self {
            case .quiet:   return 200
            case .normal:  return 100
            case .verbose: return 50
            }
        }

        // CPU moves are interesting when they gain this many centipawns
        var cpuGainThreshold: Int { 50 }
    }

    struct EvaluationResult {
        let classification: String   // "Blunder", "Mistake", "Inaccuracy", "Brilliant", "Good", "Instructive"
        let scoreBefore: Int         // centipawns, white-positive
        let scoreAfter: Int
        let delta: Int               // moving-side loss (positive = bad for mover)
        let shouldTriggerCoaching: Bool
    }

    // MARK: - State

    var verbosity: Verbosity = .normal

    // MARK: - Evaluation

    /// Evaluates a single move by asking Stockfish to score both positions.
    /// - Parameters:
    ///   - prevFEN: FEN before the move.
    ///   - newFEN:  FEN after the move.
    ///   - lan:     Move in long algebraic notation (for logging).
    ///   - isWhiteMove: True if white just moved.
    ///   - isPlayerMove: False for CPU moves — uses instructive classification instead.
    func evaluateMove(
        prevFEN: String,
        newFEN: String,
        lan: String,
        isWhiteMove: Bool,
        isPlayerMove: Bool
    ) async throws -> EvaluationResult {
        let stockfish = StockfishManager.shared
        let scoreBefore = try await stockfish.evaluate(fen: prevFEN)
        let scoreAfter  = try await stockfish.evaluate(fen: newFEN)

        // Delta from the moving side's perspective.
        // Positive = mover lost centipawns (bad). Negative = mover gained (good).
        let delta = isWhiteMove
            ? (scoreBefore - scoreAfter)
            : (scoreAfter  - scoreBefore)

        let classification: String
        let shouldTrigger: Bool

        if isPlayerMove {
            switch delta {
            case 200...:    classification = "Blunder"
            case 100..<200: classification = "Mistake"
            case 50..<100:  classification = "Inaccuracy"
            case ..<(-50):  classification = "Brilliant"
            default:        classification = "Good"
            }
            shouldTrigger = delta >= verbosity.playerThreshold
        } else {
            // CPU: instructive when the CPU gained significantly (player missed a response)
            let cpuGain = isWhiteMove
                ? (scoreAfter  - scoreBefore)
                : (scoreBefore - scoreAfter)
            classification = cpuGain >= verbosity.cpuGainThreshold ? "Instructive" : "Good"
            shouldTrigger  = cpuGain >= verbosity.cpuGainThreshold
        }

        let result = EvaluationResult(
            classification: classification,
            scoreBefore: scoreBefore,
            scoreAfter: scoreAfter,
            delta: delta,
            shouldTriggerCoaching: shouldTrigger
        )

        let mover = isPlayerMove ? "Player" : "CPU"
        log.info(
            """
            [\(mover)] \(lan) → \(classification) \
            | cp \(scoreBefore) → \(scoreAfter) \
            | delta \(delta) \
            | coach=\(shouldTrigger)
            """
        )

        return result
    }

    // MARK: - Centipawn formatting (for LLM prompt in Phase 4)

    func formatScore(_ cp: Int) -> String {
        if cp >= 10_000  { return "checkmate for white" }
        if cp <= -10_000 { return "checkmate for black" }
        let pawns = Double(abs(cp)) / 100.0
        let side = cp > 0 ? "white" : "black"
        return String(format: "%.1f (%@ advantage)", pawns, side)
    }
}
