import PlayerzAPI
import UIKit

/// The answer's connection, kept up for a short trip out of the app.
///
/// iOS suspends an app a few seconds after it leaves the screen, and a
/// suspended app's sockets go. In Agrent the owner asked a question, switched
/// apps to send a screenshot of the wait, and came back to «no connection»:
/// the server logged the stream cancelled 4.7 s in (agri-saas #2681).
/// Holding a background task while a turn's stream is open asks iOS for the
/// usual grace (about thirty seconds), which covers most answers. Past it,
/// the turn ends in `.lostMidAnswer`.
///
/// One task per turn, ended when the turn ends, when the person stops it, or
/// when iOS says the grace is over.
@MainActor
final class AssistantKeepAlive: AssistantConnectionHold {
    private var task: UIBackgroundTaskIdentifier = .invalid

    func begin() {
        guard task == .invalid else { return }
        task = UIApplication.shared.beginBackgroundTask(withName: "Assistant") { [weak self] in
            // iOS's grace is over: give the task back, or the app is killed.
            MainActor.assumeIsolated { self?.end() }
        }
    }

    func end() {
        guard task != .invalid else { return }
        UIApplication.shared.endBackgroundTask(task)
        task = .invalid
    }
}
