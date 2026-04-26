import Testing
import Foundation

@Suite("GameViewModel")
@MainActor
struct GameViewModelTests {
    @Test("starts with white to move")
    func initialTurnIsWhite() {
        let vm = GameViewModel()
        #expect(vm.isWhiteToMove == true)
    }

    @Test("default difficulty is 5")
    func defaultDifficulty() {
        let vm = GameViewModel()
        #expect(vm.currentDifficulty == 5)
    }

    @Test("player colour defaults to white")
    func defaultPlayerColour() {
        let vm = GameViewModel()
        #expect(vm.playerColour == "white")
    }

    @Test("startNewGame resets coach messages")
    func startNewGameClearsMessages() {
        let vm = GameViewModel()
        vm.coachMessages = [CoachMessage(moveNumber: 1, mover: "You", classification: "Blunder")]
        vm.startNewGame()
        #expect(vm.coachMessages.isEmpty)
    }

    @Test("startNewGame resets turn to white")
    func startNewGameResetsTurn() {
        let vm = GameViewModel()
        vm.isWhiteToMove = false
        vm.startNewGame()
        #expect(vm.isWhiteToMove == true)
    }

    @Test("handleMove toggles turn")
    func handleMoveTogglesTurn() {
        let vm = GameViewModel()
        #expect(vm.isWhiteToMove == true)
        vm.handleMove(lan: "e2e4", newFEN: "rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1", newPGN: "1. e4")
        #expect(vm.isWhiteToMove == false)
    }

    @Test("togglePlayerColour switches white to black")
    func toggleColour() {
        let vm = GameViewModel()
        #expect(vm.playerColour == "white")
        vm.togglePlayerColour()
        #expect(vm.playerColour == "black")
        vm.togglePlayerColour()
        #expect(vm.playerColour == "white")
    }
}
