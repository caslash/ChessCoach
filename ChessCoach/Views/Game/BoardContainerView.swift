import SwiftUI
import ChessboardKit
import ChessKit

struct BoardContainerView: View {
    @Bindable var gameViewModel: GameViewModel

    // ChessboardKit's INITIAL_FEN constant is missing the g-file knights; use the correct FEN.
    private static let startFEN = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"

    @State private var chessboardModel = ChessboardModel(fen: startFEN)
    @State private var sanMoves: [String] = []
    @State private var resetID: Int = 0

    var body: some View {
        Chessboard(chessboardModel: chessboardModel)
            .onMove { move, isLegal, from, to, lan, promotionPiece in
                guard isLegal else { return }
                handleLegalMove(move: move, lan: lan)
            }
            .aspectRatio(1, contentMode: .fit)
            .id(resetID)
            .onChange(of: gameViewModel.gameID) { _, _ in
                chessboardModel = ChessboardModel(fen: Self.startFEN)
                sanMoves = []
                resetID += 1
            }
            .onChange(of: gameViewModel.isGameOver) { _, _ in
                // Phase 2+: handle game over state (e.g. disable input)
            }
    }

    // MARK: - Private

    private func handleLegalMove(move: Move, lan: String) {
        // SAN computed from pre-move game state (ChessKit uses current position to determine check/mate suffix)
        let sanString = SanSerialization.default.san(for: move, in: chessboardModel.game)
        sanMoves.append(sanString)

        // Apply move to ChessKit so position reflects post-move state
        chessboardModel.game.make(move: move)

        let newFEN = FenSerialization.default.serialize(position: chessboardModel.game.position)
        let newPGN = buildPGN(from: sanMoves)

        withAnimation(.spring(duration: 0.3)) {
            chessboardModel.setFen(newFEN, lan: lan)
            gameViewModel.handleMove(lan: lan, newFEN: newFEN, newPGN: newPGN)
        }
    }

    private func buildPGN(from moves: [String]) -> String {
        var pgn = ""
        for (index, san) in moves.enumerated() {
            if index % 2 == 0 {
                pgn += "\(index / 2 + 1). \(san)"
            } else {
                pgn += " \(san)"
                if index < moves.count - 1 { pgn += " " }
            }
        }
        return pgn
    }
}
