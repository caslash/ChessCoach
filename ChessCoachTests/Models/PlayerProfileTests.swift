import Testing
import Foundation
@testable import ChessCoach

@Suite("PlayerProfile")
struct PlayerProfileTests {
    @Test("initialises with beginner defaults")
    func defaultSkillBracket() {
        let profile = PlayerProfile()
        #expect(profile.skillBracket == "beginner")
        #expect(profile.coachingVerbosity == "normal")
        #expect(profile.preferredDifficulty == 5)
        #expect(profile.rollingACPL == 0)
        #expect(profile.gamesPlayed == 0)
    }
}
