import PlayerzAPI
import SwiftUI

/// A club's tags, at most three (CardTags, owner 2026-11-13): the price, the
/// rating when there is one, the sports, several of them as one «N спорта».
struct VenueCardTags: View {
    let price: String?
    var pricePlain = false
    let rating: (shown: String, spoken: String)?
    let sports: [String]

    var body: some View {
        ChipFlow {
            ForEach(Array(CardTags.pick(hasRating: rating != nil, sports: sports).enumerated()), id: \.offset) { _, tag in
                switch tag {
                case .price:
                    if let price { VenueFactChip(text: price, prominent: !pricePlain) }
                case .rating:
                    if let rating {
                        VenueFactChip(text: rating.shown, systemImage: "star.fill")
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel(rating.spoken)
                    }
                case .sport(let code):
                    VenueFactChip(text: GameText.sport(code))
                case .sports(let count):
                    VenueFactChip(text: String(localized: "venues.sportCount \(count)"))
                        .accessibilityLabel(VenueFacts.sports(sports).formatted(.list(type: .and)))
                }
            }
        }
    }
}
