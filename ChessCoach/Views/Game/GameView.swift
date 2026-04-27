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
                .overlay(alignment: .bottom) {
                    if gameViewModel.isCPUThinking {
                        thinkingIndicator
                    }
                }
        }
        .toolbar {
            ToolbarItemGroup(placement: .automatic) {
                GameControlsView(gameViewModel: gameViewModel)
            }
        }
        .navigationTitle("ChessCoach")
        .task {
            await gameViewModel.launchStockfish()
        }
        .alert("Engine Error", isPresented: .constant(gameViewModel.stockfishError != nil)) {
            Button("OK") { gameViewModel.stockfishError = nil }
        } message: {
            Text(gameViewModel.stockfishError ?? "")
        }
    }

    private var thinkingIndicator: some View {
        HStack(spacing: 8) {
            ProgressView()
                .scaleEffect(0.7)
            Text("CPU thinking…")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .glassEffect(.regular)
        .padding(.bottom, 16)
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }
}

#Preview {
    GameView()
}
