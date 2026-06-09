import CoreLocation

// MARK: - LocationManager
//
// Single-shot "where am I?" helper used by the share card.
// Requests When-In-Use permission, grabs one location fix, then reverse-geocodes
// it into a human-readable place label with a "in"/"at" prefix:
//
//   "at Fitness First Mitte"   (named venue / point of interest)
//   "in Berlin"                (city when no venue name)
//   "in Bavaria, Germany"      (region + country as fallback)
//
// @unchecked Sendable: all mutable state is accessed on the main thread only
// (CLLocationManagerDelegate callbacks arrive on main; we dispatch reverse-geocode
// results back to main before touching @Observable properties).

@Observable
final class LocationManager: NSObject, CLLocationManagerDelegate, @unchecked Sendable {

    static let shared = LocationManager()

    var placeLabel: String? = nil            // nil until a fix is obtained
    var prefix:     String  = "in"           // "at" for venues, "in" for areas
    var lastKnownCoordinate: CLLocationCoordinate2D? = nil

    private let manager = CLLocationManager()
    private var isRequesting = false

    private override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    // MARK: - Public

    /// Request a location fix + reverse geocode.  Safe to call multiple times.
    func requestOnce() {
        guard !isRequesting else { return }
        let status = manager.authorizationStatus
        switch status {
        case .notDetermined:
            isRequesting = true
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            fetchLocation()
        default:
            break   // denied/restricted — no-op, label stays nil
        }
    }

    // MARK: - CLLocationManagerDelegate

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if manager.authorizationStatus == .authorizedWhenInUse ||
           manager.authorizationStatus == .authorizedAlways {
            fetchLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        manager.stopUpdatingLocation()
        isRequesting = false
        guard let loc = locations.last else { return }
        lastKnownCoordinate = loc.coordinate
        reverseGeocode(loc)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        isRequesting = false
    }

    // MARK: - Private

    private func fetchLocation() {
        isRequesting = true
        manager.startUpdatingLocation()
    }

    private func reverseGeocode(_ location: CLLocation) {
        CLGeocoder().reverseGeocodeLocation(location) { [weak self] placemarks, _ in
            guard let self, let p = placemarks?.first else { return }
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                if let venue = p.name, !venue.isEmpty,
                   venue != p.locality, venue != p.administrativeArea {
                    // Named venue / POI
                    self.prefix     = "at"
                    self.placeLabel = venue
                } else if let city = p.locality {
                    self.prefix     = "in"
                    self.placeLabel = city
                } else if let region = p.administrativeArea,
                          let country = p.country {
                    self.prefix     = "in"
                    self.placeLabel = "\(region), \(country)"
                } else if let country = p.country {
                    self.prefix     = "in"
                    self.placeLabel = country
                }
            }
        }
    }
}
