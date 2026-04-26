import SwiftUI

struct WelcomeView: View {
    @Binding var hasCompletedOnboarding: Bool

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: "crown.fill")
                .font(.system(size: 80))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.accent)
                .accessibilityLabel("ChessCoach crown icon")

            VStack(spacing: 12) {
                Text("ChessCoach")
                    .font(.largeTitle.weight(.bold))

                Text("Play chess against a strong CPU opponent\nwhile a local AI coach explains your mistakes.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }

            // TODO: Phase 4 — replace with ModelPickerView flow
            Button {
                hasCompletedOnboarding = true
            } label: {
                Text("Get Started")
                    .font(.body.weight(.semibold))
                    .frame(minWidth: 200)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .accessibilityLabel("Get started and open the chess app")

            Spacer()
        }
        .padding(48)
        .frame(minWidth: 480, minHeight: 360)
    }
}

#Preview {
    WelcomeView(hasCompletedOnboarding: .constant(false))
}
