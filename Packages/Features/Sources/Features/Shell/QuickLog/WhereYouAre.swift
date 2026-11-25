import CoreLocation
import Geo
import Observation

/// Where you are, for "near you" and "you're in" guesses. It never asks on its own: it reads a
/// location only once you've allowed it, and asks only when you tap "Guess from where you are".
@MainActor
@Observable
final class WhereYouAre: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var waiting: [CheckedContinuation<GeoPoint?, Never>] = []
    /// Whether asking would show the system prompt (not yet asked).
    private(set) var canAsk = false
    /// Whether a location can be read.
    private(set) var isAllowed = false

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        refresh(manager.authorizationStatus)
    }

    /// Shows the system prompt (only when it hasn't been answered before).
    func ask() {
        guard canAsk else { return }
        manager.requestWhenInUseAuthorization()
    }

    /// Where you are now, or nil without permission or a fix.
    func current() async -> GeoPoint? {
        guard isAllowed else { return nil }
        return await withCheckedContinuation { continuation in
            waiting.append(continuation)
            if waiting.count == 1 {
                manager.requestLocation()
            }
        }
    }

    private func refresh(_ status: CLAuthorizationStatus) {
        canAsk = status == .notDetermined
        #if os(iOS)
            isAllowed = status == .authorizedWhenInUse || status == .authorizedAlways
        #else
            isAllowed = status == .authorizedAlways
        #endif
    }

    private func finish(_ point: GeoPoint?) {
        let continuations = waiting
        waiting = []
        for continuation in continuations {
            continuation.resume(returning: point)
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in self.refresh(status) }
    }

    nonisolated func locationManager(_: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let point = locations.last.map { GeoPoint(longitude: $0.coordinate.longitude, latitude: $0.coordinate.latitude) }
        Task { @MainActor in self.finish(point) }
    }

    nonisolated func locationManager(_: CLLocationManager, didFailWithError _: any Error) {
        Task { @MainActor in self.finish(nil) }
    }
}
