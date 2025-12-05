//
//  LocationManager.swift
//  Receipt Scanner
//
//  Created by AI Assistant
//

import Foundation
import CoreLocation
import Combine

class LocationManager: NSObject, ObservableObject {
    static let shared = LocationManager()
    
    private let locationManager = CLLocationManager()
    private var hasRequestedLocation = false
    
    // Country code to currency code mapping
    private let countryToCurrency: [String: String] = [
        "US": "USD", "CA": "CAD", "MX": "MXN",
        "GB": "GBP", "IE": "EUR",
        "FR": "EUR", "DE": "EUR", "IT": "EUR", "ES": "EUR", "NL": "EUR",
        "BE": "EUR", "AT": "EUR", "PT": "EUR", "FI": "EUR", "GR": "EUR",
        "LU": "EUR", "EE": "EUR", "LV": "EUR", "LT": "EUR", "SI": "EUR",
        "SK": "EUR", "CY": "EUR", "MT": "EUR",
        "CH": "CHF", "LI": "CHF",
        "JP": "JPY",
        "KR": "KRW",
        "CN": "CNY",
        "IN": "INR",
        "AU": "AUD", "NZ": "NZD",
        "BR": "BRL",
        "SE": "SEK", "NO": "NOK", "DK": "DKK",
        "PL": "PLN", "CZ": "CZK", "HU": "HUF", "RO": "RON"
    ]
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyKilometer // Lower accuracy is fine for country detection
    }
    
    /// Request location and set default currency based on country
    /// Only sets currency if it hasn't been manually set by the user
    func detectCurrencyFromLocation() {
        // Check if user has already set a currency manually
        let currentCurrency = UserDefaults.standard.string(forKey: "defaultCurrency")
        let hasManualCurrency = UserDefaults.standard.bool(forKey: "hasManualCurrency")
        
        // If user has manually set currency, don't override
        if hasManualCurrency && currentCurrency != nil {
            print("Currency already set manually, skipping location-based detection")
            return
        }
        
        // Check authorization status
        let status = locationManager.authorizationStatus
        
        switch status {
        case .notDetermined:
            // Request permission
            locationManager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            // Already authorized, get location
            startLocationUpdate()
        case .denied, .restricted:
            print("Location permission denied or restricted")
            // Fall back to device locale if available
            setCurrencyFromLocale()
        @unknown default:
            print("Unknown location authorization status")
            setCurrencyFromLocale()
        }
    }
    
    private func startLocationUpdate() {
        // Use a one-time location update
        locationManager.requestLocation()
    }
    
    private func setCurrencyFromCountryCode(_ countryCode: String) {
        guard let currencyCode = countryToCurrency[countryCode.uppercased()] else {
            print("No currency mapping found for country: \(countryCode)")
            // Fall back to locale-based detection
            setCurrencyFromLocale()
            return
        }
        
        // Only set if currency hasn't been manually set
        let hasManualCurrency = UserDefaults.standard.bool(forKey: "hasManualCurrency")
        if !hasManualCurrency {
            UserDefaults.standard.set(currencyCode, forKey: "defaultCurrency")
            print("✅ Set default currency to \(currencyCode) based on country: \(countryCode)")
        } else {
            print("Currency already set manually, not overriding with location-based detection")
        }
    }
    
    private func setCurrencyFromLocale() {
        // Fallback: try to get currency from device locale
        let locale = Locale.current
        if let currencyCode = locale.currencyCode {
            // Check if this currency is supported in our app
            let supportedCurrencies = ["USD", "EUR", "GBP", "CAD", "AUD", "JPY", "CHF", "CNY", "INR", "BRL", "SEK", "NOK", "DKK", "PLN", "CZK", "HUF", "RON", "KRW", "MXN"]
            
            if supportedCurrencies.contains(currencyCode) {
                let hasManualCurrency = UserDefaults.standard.bool(forKey: "hasManualCurrency")
                if !hasManualCurrency {
                    UserDefaults.standard.set(currencyCode, forKey: "defaultCurrency")
                    print("✅ Set default currency to \(currencyCode) based on device locale")
                }
            } else {
                print("Device locale currency \(currencyCode) not supported, keeping default USD")
            }
        }
    }
}

// MARK: - CLLocationManagerDelegate
extension LocationManager: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.first else { return }
        
        // Reverse geocode to get country code
        let geocoder = CLGeocoder()
        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, error in
            guard let self = self else { return }
            
            if let error = error {
                print("Reverse geocoding error: \(error.localizedDescription)")
                // Fall back to locale-based detection
                self.setCurrencyFromLocale()
                return
            }
            
            guard let placemark = placemarks?.first,
                  let countryCode = placemark.isoCountryCode else {
                print("Could not determine country from location")
                self.setCurrencyFromLocale()
                return
            }
            
            print("📍 Detected country: \(countryCode)")
            self.setCurrencyFromCountryCode(countryCode)
        }
        
        // Stop location updates after first successful location
        locationManager.stopUpdatingLocation()
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location error: \(error.localizedDescription)")
        // Fall back to locale-based detection
        setCurrencyFromLocale()
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        
        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            startLocationUpdate()
        case .denied, .restricted:
            print("Location permission denied")
            setCurrencyFromLocale()
        case .notDetermined:
            break
        @unknown default:
            setCurrencyFromLocale()
        }
    }
}
