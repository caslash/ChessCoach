import SwiftUI
import SwiftData

@main
struct ChessCoachApp: App {
    private let modelContainer: ModelContainer

    init() {
        do {
            modelContainer = try ModelContainer(for: GameRecord.self, PlayerProfile.self)
        } catch {
            fatalError("Failed to create SwiftData ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(modelContainer)
        .defaultSize(width: 960, height: 680)
        .windowResizability(.contentMinSize)
    }
}
