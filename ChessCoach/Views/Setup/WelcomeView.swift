import SwiftUI
import FoundationModels

struct WelcomeView: View {
    @Binding var hasCompletedOnboarding: Bool
    @State private var setupViewModel = SetupViewModel()

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: "crown.fill")
                .font(.system(size: 80))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(Color.accentColor)
                .accessibilityLabel("ChessCoach crown icon")

            VStack(spacing: 12) {
                Text("ChessCoach")
                    .font(.largeTitle.weight(.bold))

                Text("Play chess against a strong CPU opponent\nwhile a local AI coach explains your mistakes.\nEverything runs on your Mac — no internet required.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .frame(maxWidth: 360)
            }

            if case .unavailable(let reason) = setupViewModel.modelAvailability {
                availabilityWarning(reason: reason)
            }

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
        .task {
            // Skip onboarding entirely on repeat launches — model is always system-level
            hasCompletedOnboarding = true
        }
    }

    @ViewBuilder
    private func availabilityWarning(reason: SystemLanguageModel.Availability.UnavailableReason) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle")
                .foregroundStyle(.orange)
            Text("Apple Intelligence is not available. Coaching will be disabled. Enable it in System Settings → Apple Intelligence & Siri.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.leading)
        }
        .padding(12)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
        .frame(maxWidth: 360)
    }
}

#Preview {
    WelcomeView(hasCompletedOnboarding: .constant(false))
}
