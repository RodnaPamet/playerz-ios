import Foundation
import Testing

@testable import PlayerzAPI

@Suite("SportArt")
struct SportArtTests {
    @Test("every known sport has its own picture")
    func everyKnownSport() {
        let keys = Sports.known.compactMap(SportArt.key)
        #expect(keys.count == Sports.known.count)
        #expect(Set(keys).count == keys.count)
    }

    @Test("the server's names map to the files' names")
    func names() {
        #expect(SportArt.resource("FOOTBALL5") == "sport-football-5x5")
        #expect(SportArt.resource("TABLE_TENNIS") == "sport-table-tennis")
        #expect(SportArt.resource("BEACH_VOLLEYBALL") == "sport-beach-volleyball")
        #expect(SportArt.resource("CURLING") == nil)
    }

    @Test("every picture is in the app's resources")
    func bundled() throws {
        let folder = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appending(path: "Apps/Playerz/Resources/SportArt")
        for sport in Sports.known {
            let name = try #require(SportArt.resource(sport))
            #expect(FileManager.default.fileExists(atPath: folder.appending(path: "\(name).webp").path), "\(name)")
        }
    }
}
