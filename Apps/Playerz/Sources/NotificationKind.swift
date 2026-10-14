import Foundation
import PlayerzAPI

/// The kinds of email and push a person switches on or off (#375, #376, #529,
/// #550), in the web's words. The bell always shows everything.
enum NotificationKind: String, CaseIterable, Hashable {
    case confirmation, reminder, clubChanges, messages, openPlay, lessonsTaught

    var label: String {
        localized(key: "profile.kind.\(rawValue)")
    }

    func read(_ email: Components.Schemas.NotificationSettings.emailPayload) -> Bool {
        switch self {
        case .confirmation: email.confirmation
        case .reminder: email.reminder
        case .clubChanges: email.clubChanges
        case .messages: email.messages
        case .openPlay: email.openPlay
        case .lessonsTaught: email.lessonsTaught
        }
    }

    func read(_ push: Components.Schemas.NotificationSettings.pushPayload) -> Bool {
        switch self {
        case .confirmation: push.confirmation
        case .reminder: push.reminder
        case .clubChanges: push.clubChanges
        case .messages: push.messages
        case .openPlay: push.openPlay
        case .lessonsTaught: push.lessonsTaught
        }
    }

    /// One switch changed, and only it: the server leaves an absent field as it is.
    func emailChange(_ on: Bool) -> Components.Schemas.UpdateNotificationSettingsRequest.emailPayload {
        switch self {
        case .confirmation: .init(confirmation: on)
        case .reminder: .init(reminder: on)
        case .clubChanges: .init(clubChanges: on)
        case .messages: .init(messages: on)
        case .openPlay: .init(openPlay: on)
        case .lessonsTaught: .init(lessonsTaught: on)
        }
    }

    func pushChange(_ on: Bool) -> Components.Schemas.UpdateNotificationSettingsRequest.pushPayload {
        switch self {
        case .confirmation: .init(confirmation: on)
        case .reminder: .init(reminder: on)
        case .clubChanges: .init(clubChanges: on)
        case .messages: .init(messages: on)
        case .openPlay: .init(openPlay: on)
        case .lessonsTaught: .init(lessonsTaught: on)
        }
    }
}

extension Dictionary where Key == NotificationKind, Value == Bool {
    /// A switch's state, on until the server says otherwise; a key path can
    /// hold this subscript, which `[kind, default: true]` cannot.
    subscript(on kind: NotificationKind) -> Bool {
        get { self[kind] ?? true }
        set { self[kind] = newValue }
    }
}
