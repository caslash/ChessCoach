import Foundation
import Observation

// Retained for spec §3 structure compliance.
// Phase 4 uses FoundationModels (Apple Intelligence) — no download required.
// This class is available for Phase 5+ if a fallback GGUF model download is added.
@MainActor
@Observable
final class ModelDownloadManager {
    enum ModelOption: CaseIterable {
        case llama3B
        case qwen7B

        var displayName: String {
            switch self {
            case .llama3B: return "Llama 3.2 3B"
            case .qwen7B:  return "Qwen2.5 7B"
            }
        }

        var sizeLabel: String {
            switch self {
            case .llama3B: return "~2.0 GB"
            case .qwen7B:  return "~4.7 GB"
            }
        }

        var qualityLabel: String {
            switch self {
            case .llama3B: return "Faster, good quality"
            case .qwen7B:  return "Slower, better quality"
            }
        }
    }
}
