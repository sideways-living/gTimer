import CoreLocation
import Foundation
import MapKit

@Observable
final class LocationManager: NSObject, CLLocationManagerDelegate {
  static let shared = LocationManager()

  var currentLocation: CLLocation?
  var locationName: String?
  var countryCode: String?
  var authorizationStatus: CLAuthorizationStatus = .notDetermined
  var hasLocationPermission: Bool {
    #if os(macOS)
    authorizationStatus == .authorizedAlways
    #else
    authorizationStatus == .authorizedWhenInUse ||
      authorizationStatus == .authorizedAlways
    #endif
  }
  var needsSystemSettingsForPermission: Bool {
    authorizationStatus == .denied || authorizationStatus == .restricted
  }
  var authorizationStatusMessage: String {
    switch authorizationStatus {
    case .notDetermined:
      return "Location permission has not been requested yet."
    case .restricted:
      return "Location access is restricted in system settings."
    case .denied:
      return "Location access is blocked in system settings."
    case .authorizedAlways, .authorizedWhenInUse:
      return "Location access is allowed."
    @unknown default:
      return "Location permission status is unknown."
    }
  }

  private let manager = CLLocationManager()
  private var pendingContinuation: CheckedContinuation<CLLocation?, Never>?
  private var continuationResumed = false
  private var pendingAuthorizationContinuation: CheckedContinuation<Bool, Never>?
  private var authorizationContinuationResumed = false

  override init() {
    super.init()
    manager.delegate = self
    manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    authorizationStatus = manager.authorizationStatus
  }

  // Call this when the user explicitly opts in to location recording.
  func requestWhenInUsePermission() {
    refreshAuthorizationStatus()
    guard authorizationStatus == .notDetermined else { return }
    manager.requestWhenInUseAuthorization()
  }

  func requestWhenInUsePermissionIfNeeded(timeout: TimeInterval = 12.0) async -> Bool {
    refreshAuthorizationStatus()
    if hasLocationPermission { return true }
    guard authorizationStatus == .notDetermined else { return false }

    resumeAuthorizationContinuation()

    return await withCheckedContinuation { continuation in
      authorizationContinuationResumed = false
      pendingAuthorizationContinuation = continuation
      manager.requestWhenInUseAuthorization()

      Task {
        try? await Task.sleep(for: .seconds(timeout))
        self.refreshAuthorizationStatus()
        self.resumeAuthorizationContinuation()
      }
    }
  }

  func refreshAuthorizationStatus() {
    authorizationStatus = manager.authorizationStatus
  }

  // Fire-and-forget: request a fresh location in background.
  // Used to warm up a fix before the user taps "log dose".
  func requestLocationInBackground() {
    guard hasLocationPermission else { return }
    manager.requestLocation()
  }

  // Returns a location for dose logging.
  // Returns the current fix immediately if it is fresh (< 5 min),
  // otherwise requests one-shot and waits up to `timeout` seconds.
  // Safe to call concurrently — a second call cancels the first pending wait.
  func captureForDose(timeout: TimeInterval = 5.0) async -> CLLocation? {
    guard hasLocationPermission else { return nil }

    if let loc = currentLocation, Date().timeIntervalSince(loc.timestamp) < 300 {
      return loc
    }

    // If a continuation is already pending, resolve it immediately so it is
    // never abandoned, then proceed with a new one.
    resumeContinuation(with: currentLocation)

    return await withCheckedContinuation { continuation in
      continuationResumed = false
      pendingContinuation = continuation
      manager.requestLocation()

      Task {
        try? await Task.sleep(for: .seconds(timeout))
        self.resumeContinuation(with: self.currentLocation)
      }
    }
  }

  private func resumeContinuation(with location: CLLocation?) {
    guard !continuationResumed else { return }
    continuationResumed = true
    pendingContinuation?.resume(returning: location)
    pendingContinuation = nil
  }

  private func resumeAuthorizationContinuation() {
    guard !authorizationContinuationResumed else { return }
    authorizationContinuationResumed = true
    pendingAuthorizationContinuation?.resume(returning: hasLocationPermission)
    pendingAuthorizationContinuation = nil
  }

  // MARK: - CLLocationManagerDelegate

  func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    currentLocation = locations.last
    if let loc = locations.last {
      reverseGeocode(loc)
      resumeContinuation(with: loc)
    }
  }

  func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
    resumeContinuation(with: currentLocation)
  }

  func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
    authorizationStatus = manager.authorizationStatus
    resumeAuthorizationContinuation()
  }

  private func reverseGeocode(_ location: CLLocation) {
    Task {
      guard let request = MKReverseGeocodingRequest(location: location),
            let item = try? await request.mapItems.first
      else { return }

      let address = item.addressRepresentations
      let locationName = address?.cityWithContext(.full)
        ?? address?.fullAddress(includingRegion: true, singleLine: true)
      let countryCode = Self.countryCode(for: address?.regionName)

      await MainActor.run { [weak self] in
        self?.countryCode = countryCode
        self?.locationName = locationName
      }
    }
  }

  private static func countryCode(for regionName: String?) -> String? {
    guard let regionName = regionName?.trimmingCharacters(in: .whitespacesAndNewlines),
          !regionName.isEmpty
    else { return nil }

    return EmergencyNumberCatalogue.countries.first {
      $0.name.caseInsensitiveCompare(regionName) == .orderedSame
    }?.code
  }
}
