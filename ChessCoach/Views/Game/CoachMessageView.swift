import SwiftUI

struct CoachMessageView: View {
    let message: CoachMessage

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Move \(message.moveNumber) · \(message.mover)")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(message.classification)
                .font(.caption2.weight(.semibold))
                .textCase(.uppercase)
                .foregroundStyle(message.badgeColour)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .glassEffect(.regular)

            HStack(alignment: .bottom, spacing: 2) {
                Text(message.text.isEmpty ? " " : message.text)
                    .font(.body)
                    .lineSpacing(4)

                if message.isStreaming {
                    BlinkingCursor()
                }
            }
        }
        .padding(16)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct BlinkingCursor: View {
    @State private var opacity: Double = 1

    var body: some View {
        Text("|")
            .font(.body)
            .opacity(opacity)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                    opacity = 0
                }
            }
    }
}
