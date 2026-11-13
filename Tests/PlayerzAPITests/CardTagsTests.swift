import Testing

@testable import PlayerzAPI

@Suite("CardTags")
struct CardTagsTests {
    @Test("never more than three; many sports are one tag")
    func many() {
        let all = Sports.known
        #expect(CardTags.pick(hasRating: true, sports: all) == [.price, .rating, .sports(all.count)])
        #expect(CardTags.pick(hasRating: false, sports: all) == [.price, .sports(all.count)])
    }

    @Test("the sports by name while they fit")
    func fit() {
        #expect(CardTags.pick(hasRating: true, sports: ["TENNIS"]) == [.price, .rating, .sport("TENNIS")])
        #expect(CardTags.pick(hasRating: false, sports: ["TENNIS", "PADEL"]) == [.price, .sport("TENNIS"), .sport("PADEL")])
        #expect(CardTags.pick(hasRating: true, sports: ["TENNIS", "PADEL"]) == [.price, .rating, .sports(2)])
        #expect(CardTags.pick(hasRating: false, sports: []) == [.price])
    }
}
