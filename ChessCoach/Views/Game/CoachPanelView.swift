import SwiftUI

struct CoachPanelView: View {
    @Bindable var gameViewModel: GameViewModel

    var body: some View {
        Group {
            if gameViewModel.coachMessages.isEmpty {
                placeholderView
            } else {
                messageListView
            }
        }
    }

    private var placeholderView: some View {
        VStack(spacing: 8) {
            Text("Your coach is watching.")
                .font(.body)
                .foregroundStyle(.secondary)
            Text("I'll speak up when it matters.")
                .font(.body)
                .foregroundStyle(.tertiary)
        }
        .multilineTextAlignment(.center)
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var messageListView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(gameViewModel.coachMessages) { message in
                        CoachMessageView(message: message)
                            .id(message.id)
                    }
                }
                .padding(16)
            }
            .onChange(of: gameViewModel.coachMessages.count) { _, _ in
                if let last = gameViewModel.coachMessages.last {
                    withAnimation(.spring(duration: 0.3)) {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
    }
}
