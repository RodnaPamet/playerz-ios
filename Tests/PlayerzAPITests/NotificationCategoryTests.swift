import Testing

@testable import PlayerzAPI

/// The bell's groups (playerz-ios#56, projectZ#677): the chips follow the
/// server's modules; «Всички» lists everything either way.
@Suite("Notification groups")
struct NotificationCategoryTests {
    @Test("every module on: a chip for each group but «other»")
    func allModules() {
        let chips = NotificationCategory.chips(Modules(openPlay: true, messaging: true, coaches: true, ranking: true))
        #expect(chips == [.bookings, .games, .messages, .lessons, .tournaments])
    }

    @Test("a module off takes its chip away; bookings always stay")
    func modulesOff() {
        #expect(NotificationCategory.chips(Modules(openPlay: false, messaging: false, coaches: false, ranking: false)) == [.bookings])
        #expect(NotificationCategory.chips(Modules(openPlay: false, messaging: true, coaches: false, ranking: true))
            == [.bookings, .games, .messages, .tournaments])
    }

    @Test("the server's group names are the chips' raw values")
    func serverNames() {
        for category in Components.Schemas.NotificationCategory.allCases {
            #expect(NotificationCategory(rawValue: category.rawValue) != nil)
        }
    }
}
