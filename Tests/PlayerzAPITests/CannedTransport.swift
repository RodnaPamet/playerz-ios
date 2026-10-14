import Foundation
import HTTPTypes
import OpenAPIRuntime

/// Answers each operation with a captured status and body: what the decoding
/// suites play back through the generated client.
struct Canned: ClientTransport {
    let replies: [String: (Int, String)]

    func send(
        _ request: HTTPRequest,
        body: HTTPBody?,
        baseURL: URL,
        operationID: String
    ) async throws -> (HTTPResponse, HTTPBody?) {
        guard let (status, json) = replies[operationID] else {
            return (HTTPResponse(status: .notFound), nil)
        }
        return (
            HTTPResponse(status: .init(code: status), headerFields: [.contentType: "application/json"]),
            HTTPBody(json)
        )
    }
}
