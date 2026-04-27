import Foundation
import Observation

@MainActor
@Observable
final class GameViewModel {
    // MARK: - Game state
    var isWhiteToMove: Bool = true
    var currentDifficulty: Int = 5
    var playerColour: String = "white"
    var isGameOver: Bool = false
    var gameResultMessage: String = ""
    var stockfishError: String? = nil

    // MARK: - Coach
    var coachMessages: [CoachMessage] = []

    // MARK: - Position tracking (set by BoardContainerView after each legal move)
    var currentFEN: String = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"
    var pgn: String = ""
    var moveNumber: Int = 1

    // Incremented by startNewGame() — BoardContainerView observes this to reset ChessboardModel
    var gameID: UUID = UUID()

    // Pending CPU move LAN — BoardContainerView observes this to apply the move visually
    var pendingCPUMove: String? = nil

    // True while Stockfish is computing a CPU move
    var isCPUThinking: Bool = false

    // MARK: - Private

    private var stockfishLaunched = false
    private var coachingEngine: CoachingEngine { CoachingEngine.shared }

    // MARK: - Lifecycle

    func launchStockfish() async {
        guard !stockfishLaunched else { return }
        do {
            try await StockfishManager.shared.launch()
            stockfishLaunched = true
        } catch {
            stockfishError = error.localizedDescription
        }
    }

    // MARK: - Actions

    func startNewGame() {
        gameID = UUID()
        isWhiteToMove = true
        isGameOver = false
        gameResultMessage = ""
        stockfishError = nil
        coachMessages = []
        currentFEN = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"
        pgn = ""
        moveNumber = 1
        pendingCPUMove = nil
        isCPUThinking = false

        Task {
            do {
                try await StockfishManager.shared.newGame()
                if playerColour == "black" {
                    await triggerCPUMove()
                }
            } catch {
                stockfishError = error.localizedDescription
            }
        }
    }

    func togglePlayerColour() {
        playerColour = playerColour == "white" ? "black" : "white"
    }

    // MARK: - Human move

    // Called by BoardContainerView after each legal human move.
    func handleMove(lan: String, newFEN: String, newPGN: String) {
        let prevFEN = currentFEN
        let wasWhiteMove = isWhiteToMove

        currentFEN = newFEN
        pgn = newPGN
        isWhiteToMove.toggle()
        if isWhiteToMove { moveNumber += 1 }

        let cpuTurnNow = isCPUTurn()

        Task {
            // Evaluate player's move (sequential — same Stockfish actor as CPU move request).
            await evaluateAndRecord(
                prevFEN: prevFEN,
                newFEN: newFEN,
                lan: lan,
                isWhiteMove: wasWhiteMove,
                isPlayerMove: true
            )
            // CPU move starts only after evaluation is complete (no pipe contention).
            if cpuTurnNow && !isGameOver {
                await triggerCPUMove()
            }
        }
    }

    // MARK: - CPU move

    // Called by BoardContainerView once it has applied the CPU move visually.
    func cpuMoveApplied(lan: String, newFEN: String, newPGN: String) {
        let prevFEN = currentFEN
        let wasWhiteMove = isWhiteToMove

        pendingCPUMove = nil
        currentFEN = newFEN
        pgn = newPGN
        isWhiteToMove.toggle()
        if isWhiteToMove { moveNumber += 1 }

        Task {
            await evaluateAndRecord(
                prevFEN: prevFEN,
                newFEN: newFEN,
                lan: lan,
                isWhiteMove: wasWhiteMove,
                isPlayerMove: false
            )
        }
    }

    // MARK: - Private

    private func triggerCPUMove() async {
        guard !isGameOver else { return }
        isCPUThinking = true
        do {
            let lan = try await StockfishManager.shared.requestMove(
                fen: currentFEN,
                difficulty: currentDifficulty
            )
            pendingCPUMove = lan
        } catch {
            stockfishError = error.localizedDescription
        }
        isCPUThinking = false
    }

    private func evaluateAndRecord(
        prevFEN: String,
        newFEN: String,
        lan: String,
        isWhiteMove: Bool,
        isPlayerMove: Bool
    ) async {
        do {
            let result = try await coachingEngine.evaluateMove(
                prevFEN: prevFEN,
                newFEN: newFEN,
                lan: lan,
                isWhiteMove: isWhiteMove,
                isPlayerMove: isPlayerMove
            )
            // Phase 4: if result.shouldTriggerCoaching → call LLMManager, append streaming CoachMessage
            _ = result
        } catch {
            // Evaluation errors are non-fatal — game continues without coaching
        }
    }

    private func isCPUTurn() -> Bool {
        let cpuIsWhite = playerColour == "black"
        return cpuIsWhite ? isWhiteToMove : !isWhiteToMove
    }
}
