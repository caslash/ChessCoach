import SwiftUI

// Phase 4 uses FoundationModels (Apple Intelligence) — no model download required.
// This view is retained for spec §3 structure compliance and future GGUF fallback (Phase 5+).
struct ModelDownloadView: View {
    var body: some View {
        Text("Model download — not needed with Apple Intelligence")
            .padding()
    }
}
