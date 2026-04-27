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

    // MARK: - Coaching prompt types

    struct CoachingPrompt {
        let systemPrompt: String
        let userPrompt: String
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

    // MARK: - Centipawn formatting (for LLM prompt)

    func formatScore(_ cp: Int) -> String {
        if cp >= 10_000  { return "checkmate for white" }
        if cp <= -10_000 { return "checkmate for black" }
        let pawns = Double(abs(cp)) / 100.0
        let side = cp > 0 ? "white" : "black"
        return String(format: "%.1f (%@ advantage)", pawns, side)
    }

    // MARK: - Prompt building

    /// Constructs the system and user prompts to send to the LLM for a coaching moment.
    func buildPrompt(
        result: EvaluationResult,
        lan: String,
        isPlayerMove: Bool,
        mover: String,
        moveNumber: Int,
        pgn: String,
        currentFEN: String,
        skillBracket: String
    ) -> CoachingPrompt {
        let systemPrompt = """
            You are a friendly, knowledgeable chess coach sitting beside the player as they play.
            Your job is to help them understand what just happened and why — not to quiz them.

            When the player makes an error:
            - Gently and clearly name what went wrong (e.g. "that move leaves your king exposed on
              the back rank" or "moving that pawn let the knight into a strong outpost on d5")
            - Briefly explain the chess concept it violated — king safety, piece activity, pawn
              structure, tactical patterns, etc.
            - If helpful, note what to watch for going forward — but never say what specific move
              they should have played

            When the CPU plays an instructive move:
            - Point out what made it strong or effective
            - Name the concept or pattern (fork, pin, outpost, tempo gain, etc.)
            - Help the player recognise this pattern so they can use or counter it in future

            Rules:
            - Never ask rhetorical questions. The player cannot respond, so every message must be
              self-contained and genuinely informative on its own.
            - Never reveal the specific best move Stockfish recommended.
            - Never say "you should have played [move]" or reference specific square notation
              unless the player is at STRONG level.
            - Be warm and encouraging in tone, never critical or discouraging.
            - Keep responses concise: 2–4 sentences for simple errors, up to 6 for complex concepts.
            - Adapt language to player level: \(skillBracket.uppercased())
              - BEGINNER: plain language, name pieces not squares, explain all terms used
              - INTERMEDIATE: standard chess vocabulary, light use of notation
              - STRONG: full chess terminology and notation freely used
            """

        let moveBy = isPlayerMove ? "the player" : "the CPU opponent"

        // Avoid FEN strings and LAN notation in the prompt — FoundationModels'
        // language detector treats them as non-English and throws unsupportedLanguageOrLocale.
        // Describe the position in natural language only.
        let recentMoves: String = {
            guard !pgn.isEmpty else { return "The game just started." }
            // Trim to the last 80 chars of PGN so the prompt stays short
            let trimmed = pgn.count > 80 ? "..." + pgn.suffix(80) : pgn
            return "Recent moves: \(trimmed)"
        }()

        let userPrompt = """
            Chess coaching context — move \(moveNumber) of the game.
            This move was made by \(moveBy).
            Move quality classification: \(result.classification)
            Position evaluation before the move: \(formatScore(result.scoreBefore))
            Position evaluation after the move: \(formatScore(result.scoreAfter))
            \(recentMoves)

            Please give a concise coaching response about this move.
            """

        return CoachingPrompt(systemPrompt: systemPrompt, userPrompt: userPrompt)
    }
}
