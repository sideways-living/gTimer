import CoreLocation
import Foundation

@Observable
final class LocationManager: NSObject, CLLocationManagerDelegate {
  static let shared = LocationManager()

  var currentLocation: CLLocation?
  var locationName: String?
  private let manager = CLLocationManager()

  override init() {
    super.init()
    manager.delegate = self
    manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
  }

  func requestLocation() {
    manager.requestWhenInUseAuthorization()
    manager.requestLocation()
  }

  func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    currentLocation = locations.last
    if let loc = locations.last {
      reverseGeocode(loc)
    }
  }

  func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {}

  private func reverseGeocode(_ location: CLLocation) {
    CLGeocoder().reverseGeocodeLocation(location) { [weak self] placemarks, _ in
      if let place = placemarks?.first {
        self?.locationName = [place.locality, place.country].compactMap { $0 }.joined(separator: ", ")
      }
    }
  }
}
