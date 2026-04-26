import SwiftUI

struct GameControlsView: View {
    @Bindable var gameViewModel: GameViewModel
    @State private var showingSettings = false

    var body: some View {
        GlassEffectContainer {
            HStack(spacing: 12) {
                Button {
                    gameViewModel.startNewGame()
                } label: {
                    Label("New Game", systemImage: "arrow.counterclockwise")
                }
                .glassEffect(.regular.interactive())
                .accessibilityLabel("Start a new game")

                Divider()
                    .frame(height: 20)

                Button {
                    gameViewModel.togglePlayerColour()
                } label: {
                    Label(
                        gameViewModel.playerColour == "white" ? "Playing White" : "Playing Black",
                        systemImage: gameViewModel.playerColour == "white" ? "circle.fill" : "circle"
                    )
                }
                .glassEffect(.regular.interactive())
                .accessibilityLabel("Toggle player colour, currently \(gameViewModel.playerColour)")

                Divider()
                    .frame(height: 20)

                HStack(spacing: 8) {
                    Text("Difficulty")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Slider(value: difficultyBinding, in: 1...10, step: 1)
                        .frame(minWidth: 120, maxWidth: 160)
                        .accessibilityLabel("Difficulty level \(gameViewModel.currentDifficulty) of 10")
                    Text("\(gameViewModel.currentDifficulty)")
                        .font(.callout.monospacedDigit())
                        .frame(width: 20)
                }
                .padding(.horizontal, 8)
                .glassEffect(.regular)

                Divider()
                    .frame(height: 20)

                Button {
                    showingSettings = true
                } label: {
                    Label("Settings", systemImage: "gearshape")
                }
                .glassEffect(.regular.interactive())
                .accessibilityLabel("Open settings")
                .sheet(isPresented: $showingSettings) {
                    SettingsView()
                        .frame(minWidth: 400, minHeight: 300)
                }
            }
            .padding(.horizontal, 8)
        }
    }

    private var difficultyBinding: Binding<Double> {
        Binding(
            get: { Double(gameViewModel.currentDifficulty) },
            set: { gameViewModel.currentDifficulty = Int($0) }
        )
    }
}
