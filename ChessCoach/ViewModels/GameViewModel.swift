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

    // True while Stockfish is computing a move
    var isCPUThinking: Bool = false

    // MARK: - Private

    private var stockfish: StockfishManager { StockfishManager.shared }
    private var stockfishLaunched = false

    // MARK: - Lifecycle

    func launchStockfish() async {
        guard !stockfishLaunched else { return }
        do {
            try await stockfish.launch()
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
                try await stockfish.newGame()
                // If player is black, CPU (white) moves first
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

    // Called by BoardContainerView after each legal human move.
    func handleMove(lan: String, newFEN: String, newPGN: String) {
        currentFEN = newFEN
        pgn = newPGN
        isWhiteToMove.toggle()
        if isWhiteToMove { moveNumber += 1 }

        // Phase 3 will pass to CoachingEngine for eval delta here.

        // Trigger CPU response if it's now the CPU's turn
        let cpuIsWhite = playerColour == "black"
        let cpuTurnNow = cpuIsWhite ? isWhiteToMove : !isWhiteToMove
        if cpuTurnNow && !isGameOver {
            Task { await triggerCPUMove() }
        }
    }

    // MARK: - CPU move

    private func triggerCPUMove() async {
        guard !isGameOver else { return }
        isCPUThinking = true
        do {
            let lan = try await stockfish.requestMove(fen: currentFEN, difficulty: currentDifficulty)
            pendingCPUMove = lan
        } catch {
            stockfishError = error.localizedDescription
        }
        isCPUThinking = false
    }

    // Called by BoardContainerView once it has applied the CPU move visually.
    func cpuMoveApplied(lan: String, newFEN: String, newPGN: String) {
        pendingCPUMove = nil
        currentFEN = newFEN
        pgn = newPGN
        isWhiteToMove.toggle()
        if isWhiteToMove { moveNumber += 1 }
        // Phase 3: evaluate CPU move for instructional coaching here.
    }
}
