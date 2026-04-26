import Testing
import Foundation

@Suite("CoachMessage")
struct CoachMessageTests {
    @Test("initialises with isStreaming true and empty text")
    func initialStreamingState() {
        let msg = CoachMessage(moveNumber: 5, mover: "You", classification: "Blunder")
        #expect(msg.isStreaming == true)
        #expect(msg.text.isEmpty)
        #expect(msg.mover == "You")
        #expect(msg.moveNumber == 5)
        #expect(msg.classification == "Blunder")
    }

    @Test("badge colour names differ across classifications")
    func badgeColourNames() {
        let blunder = CoachMessage(moveNumber: 1, mover: "You", classification: "Blunder")
        let mistake = CoachMessage(moveNumber: 1, mover: "You", classification: "Mistake")
        let inaccuracy = CoachMessage(moveNumber: 1, mover: "You", classification: "Inaccuracy")
        let instructive = CoachMessage(moveNumber: 1, mover: "CPU", classification: "Instructive")
        #expect(blunder.badgeColourName == "red")
        #expect(mistake.badgeColourName == "orange")
        #expect(inaccuracy.badgeColourName == "yellow")
        #expect(instructive.badgeColourName == "blue")
    }
}
