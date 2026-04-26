import Testing
import Foundation
@testable import ChessCoach

@Suite("GameRecord")
struct GameRecordTests {
    @Test("initialises with expected values")
    func defaultValues() {
        let record = GameRecord(
            pgn: "1. e4 e5",
            playerColour: "white",
            difficulty: 5,
            result: "win",
            acpl: 32.5,
            blunderCount: 1,
            mistakeCount: 2
        )
        #expect(record.difficulty == 5)
        #expect(record.playerColour == "white")
        #expect(record.blunderCount == 1)
        #expect(record.mistakeCount == 2)
        #expect(record.result == "win")
        #expect(record.acpl == 32.5)
    }
}
