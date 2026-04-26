import SwiftUI

struct GameView: View {
    @State private var gameViewModel = GameViewModel()

    var body: some View {
        NavigationSplitView {
            CoachPanelView(gameViewModel: gameViewModel)
                .navigationSplitViewColumnWidth(min: 260, ideal: 280, max: 320)
        } detail: {
            BoardContainerView(gameViewModel: gameViewModel)
                .aspectRatio(1, contentMode: .fit)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .toolbar {
            ToolbarItemGroup(placement: .automatic) {
                GameControlsView(gameViewModel: gameViewModel)
            }
        }
        .navigationTitle("ChessCoach")
    }
}

#Preview {
    GameView()
}
