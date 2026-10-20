import SwiftUI
import UniformTypeIdentifiers

/// The export, for the Files sheet: the server's bytes, named as the web names them.
struct ExportFile: FileDocument {
    static let readableContentTypes: [UTType] = [.json]
    let data: Data
    let name: String

    init(data: Data, now: Date = .now) {
        self.data = data
        // The date in Sofia, as the server names the file it serves.
        let sofia = TimeZone(identifier: "Europe/Sofia") ?? .current
        let day = now.formatted(Date.ISO8601FormatStyle(timeZone: sofia).year().month().day())
        self.name = "playerz-data-\(day).json"
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
        name = "playerz-data.json"
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
