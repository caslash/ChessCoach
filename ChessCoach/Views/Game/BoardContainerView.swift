import SwiftUI
import ChessboardKit
import ChessKit

struct BoardContainerView: View {
    @Bindable var gameViewModel: GameViewModel

    @State private var chessboardModel = ChessboardModel(fen: INITIAL_FEN)
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
            .onChange(of: gameViewModel.moveNumber) { oldValue, newValue in
                if newValue == 1 && oldValue > 1 {
                    resetID += 1
                    sanMoves = []
                }
            }
            .onChange(of: gameViewModel.isGameOver) { _, _ in
                // Phase 2+: handle game over state (e.g. disable input)
            }
    }

    // MARK: - Private

    private func handleLegalMove(move: Move, lan: String) {
        let sanString = SanSerialization.default.san(for: move, in: chessboardModel.game)
        sanMoves.append(sanString)

        let newFEN = FenSerialization.default.serialize(position: chessboardModel.game.position)
        let newPGN = buildPGN(from: sanMoves)

        withAnimation(.spring(duration: 0.3)) {
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
