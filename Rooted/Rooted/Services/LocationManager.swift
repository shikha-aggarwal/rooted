//
//  LocationManager.swift
//  Rooted
//
//  Requests location on first launch and reverse-geocodes it to a city/region string
//  stored in AppStorage("userRegion").
//

import CoreLocation
import SwiftUI

@Observable
final class LocationManager: NSObject {
    private let manager = CLLocationManager()
    private let geocoder = CLGeocoder()

    // Writes directly into the shared AppStorage keys.
    @ObservationIgnored
    @AppStorage("userRegion") private var userRegion = "San Francisco, CA"
    @ObservationIgnored
    @AppStorage("userLat") private var userLat: Double = 0
    @ObservationIgnored
    @AppStorage("userLng") private var userLng: Double = 0

    @ObservationIgnored
    private var didResolve = false

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyThreeKilometers
    }

    func requestIfNeeded() {
        // If we already have a non-default region, skip.
        guard !didResolve else { return }
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        default:
            break
        }
    }
}

extension LocationManager: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if manager.authorizationStatus == .authorizedWhenInUse ||
           manager.authorizationStatus == .authorizedAlways {
            manager.requestLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.first, !didResolve else { return }
        // Store coordinates for coordinate-based species lookup.
        let lat = location.coordinate.latitude
        let lng = location.coordinate.longitude
        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, _ in
            guard let self, let placemark = placemarks?.first else { return }
            let city    = placemark.locality ?? placemark.administrativeArea ?? ""
            let country = placemark.country ?? ""
            let region  = [city, country].filter { !$0.isEmpty }.joined(separator: ", ")
            if !region.isEmpty {
                DispatchQueue.main.async {
                    self.userRegion = region
                    self.userLat    = lat
                    self.userLng    = lng
                    self.didResolve = true
                }
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // If location fails, try network-based (coarse) location as fallback.
        if manager.desiredAccuracy != kCLLocationAccuracyKilometer {
            manager.desiredAccuracy = kCLLocationAccuracyKilometer
            manager.requestLocation()
        }
        // If fallback also fails, keeps existing userRegion value.
    }
}
