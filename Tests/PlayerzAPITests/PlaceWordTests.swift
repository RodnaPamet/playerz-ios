import Testing

@testable import PlayerzAPI

@Suite("PlaceWord")
struct PlaceWordTests {
    @Test("every known sport has its word, as the owner mapped them")
    func mapping() {
        #expect(PlaceWord.of("TENNIS") == .court)
        #expect(PlaceWord.of("PADEL") == .court)
        #expect(PlaceWord.of("SQUASH") == .court)
        #expect(PlaceWord.of("FOOTBALL5") == .pitch)
        #expect(PlaceWord.of("BASKETBALL") == .pitch)
        #expect(PlaceWord.of("BEACH_VOLLEYBALL") == .pitch)
        #expect(PlaceWord.of("TABLE_TENNIS") == .table)
        #expect(PlaceWord.of("CHESS") == .table)
        #expect(PlaceWord.of("ESPORTS") == .hall)
        #expect(PlaceWord.of("KARTING") == .track)
        #expect(PlaceWord.of("CYCLING") == .route)
        #expect(PlaceWord.of("CURLING") == .spot)
        // No known sport is left to the generic word.
        #expect(Sports.known.allSatisfy { PlaceWord.of($0) != .spot })
    }

    @Test("several sports share their word only when they agree")
    func common() {
        #expect(PlaceWord.common(["TENNIS", "PADEL"]) == .court)
        #expect(PlaceWord.common(["TENNIS", "FOOTBALL5"]) == .spot)
        #expect(PlaceWord.common([String]()) == .spot)
    }

    @Test("gender for the adjectives")
    func gender() {
        #expect(PlaceWord.court.gender == .masculine)
        #expect(PlaceWord.pitch.gender == .neuter)
        #expect(PlaceWord.table.gender == .feminine)
        #expect(PlaceWord.spot.gender == .neuter)
    }
}
