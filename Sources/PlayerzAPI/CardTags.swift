/// The tags under a club's card (owner 2026-11-13: "put a rule of 3 tags
/// max, one tag for many sports"): the price, the rating when there is one,
/// then the sports. Sports that do not all fit in what is left become one
/// tag, «N спорта».
public enum CardTags {
    public enum Tag: Equatable, Sendable {
        case price
        case rating
        case sport(String)
        case sports(Int)
    }

    public static let max = 3

    public static func pick(hasRating: Bool, sports: [String]) -> [Tag] {
        var tags: [Tag] = [.price]
        if hasRating { tags.append(.rating) }
        let room = max - tags.count
        if sports.count <= room {
            tags += sports.map(Tag.sport)
        } else {
            tags.append(.sports(sports.count))
        }
        return tags
    }
}
