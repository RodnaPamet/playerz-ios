import CoreLocation
import Foundation

/// One location fix, on demand.
///
/// ═══ WHY IT ASKS ONLY WHEN ASKED ═══
///
/// Same reasoning as push: the prompt is a one-shot resource. Requesting
/// location at launch, before the user has expressed any interest in "near me",
/// spends it at the moment the request looks least justified — and iOS shows
/// the app's purpose string with no context to make sense of it.
///
/// So nothing happens until the user taps "Near me".
///
/// ═══ WHY A CONTINUATION AND NOT A PUBLISHER ═══
///
/// One fix, then done. CLLocationManager is delegate-based, and the caller
/// wants `let here = try await provider.current()`. A continuation MUST be
/// resumed exactly once — resuming twice traps, never resuming leaks the task
/// — so `finish` nils it out before resuming.
final class LocationProvider: NSObject, CLLocationManagerDelegate, @unchecked Sendable {
    enum Failure: Error, Equatable { case denied, unavailable }

    private let manager = CLLocationManager()
    private var waiting: CheckedContinuation<CLLocationCoordinate2D, Error>?
    private let lock = NSLock()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer  // a club list, not turn-by-turn
    }

    func current() async throws -> CLLocationCoordinate2D {
        try await withCheckedThrowingContinuation { continuation in
            lock.withLock { waiting = continuation }

            switch manager.authorizationStatus {
            case .denied, .restricted:
                finish(.failure(Failure.denied))
            case .notDetermined:
                // The delegate callback drives the next step.
                manager.requestWhenInUseAuthorization()
            case .authorizedWhenInUse, .authorizedAlways:
                manager.requestLocation()
            @unknown default:
                finish(.failure(Failure.unavailable))
            }
        }
    }

    /// Resume at most once. Everything below funnels through here.
    private func finish(_ result: Result<CLLocationCoordinate2D, Error>) {
        let continuation = lock.withLock { () -> CheckedContinuation<CLLocationCoordinate2D, Error>? in
            defer { waiting = nil }
            return waiting
        }
        continuation?.resume(with: result)
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .denied, .restricted:
            finish(.failure(Failure.denied))
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        default:
            break  // still undetermined; the prompt is on screen
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let coordinate = locations.last?.coordinate else {
            finish(.failure(Failure.unavailable))
            return
        }
        finish(.success(coordinate))
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        finish(.failure(Failure.unavailable))
    }
}
