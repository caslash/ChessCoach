import Foundation
import SwiftUI

struct CoachMessage: Identifiable {
    let id: UUID
    let moveNumber: Int
    let mover: String
    let classification: String
    var text: String
    var isStreaming: Bool

    init(
        id: UUID = UUID(),
        moveNumber: Int,
        mover: String,
        classification: String,
        text: String = "",
        isStreaming: Bool = true
    ) {
        self.id = id
        self.moveNumber = moveNumber
        self.mover = mover
        self.classification = classification
        self.text = text
        self.isStreaming = isStreaming
    }

    var badgeColourName: String {
        switch classification {
        case "Blunder":     return "red"
        case "Mistake":     return "orange"
        case "Inaccuracy":  return "yellow"
        case "Instructive": return "blue"
        default:            return "secondary"
        }
    }

    var badgeColour: Color {
        switch classification {
        case "Blunder":     return .red
        case "Mistake":     return .orange
        case "Inaccuracy":  return .yellow
        case "Instructive": return .blue
        default:            return .secondary
        }
    }
}
