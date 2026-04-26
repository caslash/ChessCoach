import Foundation
import SwiftData

@Model
final class PlayerProfile {
    var rollingACPL: Double
    var gamesPlayed: Int
    var skillBracket: String
    var preferredDifficulty: Int
    var coachingVerbosity: String
    var selectedModelFilename: String

    init(
        rollingACPL: Double = 0,
        gamesPlayed: Int = 0,
        skillBracket: String = "beginner",
        preferredDifficulty: Int = 5,
        coachingVerbosity: String = "normal",
        selectedModelFilename: String = ""
    ) {
        self.rollingACPL = rollingACPL
        self.gamesPlayed = gamesPlayed
        self.skillBracket = skillBracket
        self.preferredDifficulty = preferredDifficulty
        self.coachingVerbosity = coachingVerbosity
        self.selectedModelFilename = selectedModelFilename
    }
}
