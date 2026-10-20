import Foundation
import PlayerzAPI

/// The server's `error.code` from any generated non-2xx response.
///
/// Every operation's `Output` is its own enum, and each refusal case wraps its
/// own struct whose `body` is `.json(_Error)`. There is no protocol across
/// them to switch on, and writing the same eight cases out per operation hides
/// the one thing a screen wants: which refusal it was. So this walks the value
/// instead: the case's payload, its `body`, and the `_Error` inside.
///
/// Nil for a success, or for a response whose body is not the error envelope.
func apiErrorCode(_ output: Any) -> String? {
    apiError(output)?.code
}

/// The whole refusal: its code, the server's message, and its `details`.
func apiError(_ output: Any) -> Components.Schemas._Error.errorPayload? {
    for response in Mirror(reflecting: output).children {
        for field in Mirror(reflecting: response.value).children where field.label == "body" {
            for body in Mirror(reflecting: field.value).children {
                if let envelope = body.value as? Components.Schemas._Error {
                    return envelope.error
                }
            }
        }
    }
    return nil
}

/// A whole number in a refusal's `details`: `LESSON_PRICE_CHANGED`'s `totalCents`.
func apiErrorDetail(_ error: Components.Schemas._Error.errorPayload?, _ key: String) -> Int? {
    switch error?.details?.additionalProperties.value[key] {
    case let number as Int: number
    case let number as Double: Int(exactly: number)
    default: nil
    }
}
