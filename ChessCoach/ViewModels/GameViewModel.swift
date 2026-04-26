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

    // MARK: - Coach
    var coachMessages: [CoachMessage] = []

    // MARK: - Position tracking (set by BoardContainerView after each legal move)
    var currentFEN: String = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"
    var pgn: String = ""
    var moveNumber: Int = 1

    // MARK: - Actions

    func startNewGame() {
        isWhiteToMove = true
        isGameOver = false
        gameResultMessage = ""
        coachMessages = []
        currentFEN = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"
        pgn = ""
        moveNumber = 1
    }

    func togglePlayerColour() {
        playerColour = playerColour == "white" ? "black" : "white"
    }

    // Called by BoardContainerView after each legal move.
    // Phase 3 will route to CoachingEngine for evaluation.
    func handleMove(lan: String, newFEN: String, newPGN: String) {
        currentFEN = newFEN
        pgn = newPGN
        isWhiteToMove.toggle()
        if isWhiteToMove { moveNumber += 1 }
    }
}
