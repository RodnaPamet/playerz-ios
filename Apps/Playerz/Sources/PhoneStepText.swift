import PlayerzAPI

/// The web's words for each way the phone step can stop (`phone.step.error`).
enum PhoneStepText {
    static func error(_ error: PhoneStepError) -> String {
        switch error {
        case .invalidNumber: String(localized: "phone.step.error.PHONE_INVALID")
        case .wrongCode: String(localized: "phone.step.error.PHONE_CODE_WRONG")
        case .expiredCode: String(localized: "phone.step.error.PHONE_CODE_EXPIRED")
        case .numberInUse: String(localized: "phone.step.error.PHONE_IN_USE")
        case .unavailable: String(localized: "phone.step.error.PHONE_VERIFY_UNAVAILABLE")
        case .rateLimited: String(localized: "phone.step.error.RATE_LIMITED")
        case .notSignedIn, .failed: String(localized: "phone.step.error.FAILED")
        }
    }
}
