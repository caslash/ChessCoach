import Foundation
import SwiftData

@Model
final class GameRecord {
    var id: UUID
    var date: Date
    var pgn: String
    var playerColour: String
    var difficulty: Int
    var result: String
    var acpl: Double
    var blunderCount: Int
    var mistakeCount: Int

    init(
        id: UUID = UUID(),
        date: Date = .now,
        pgn: String,
        playerColour: String,
        difficulty: Int,
        result: String,
        acpl: Double,
        blunderCount: Int,
        mistakeCount: Int
    ) {
        self.id = id
        self.date = date
        self.pgn = pgn
        self.playerColour = playerColour
        self.difficulty = difficulty
        self.result = result
        self.acpl = acpl
        self.blunderCount = blunderCount
        self.mistakeCount = mistakeCount
    }
}
