//
//  GPS.swift
//  LidarMapper
//
//  Created by Forestry Robotics UC on 03/09/2024.
//
import SwiftUI
import CoreLocation
import Foundation
import Combine

class GPS: NSObject, ObservableObject, CLLocationManagerDelegate {
    private var locationManager = CLLocationManager()
    
    @Published var WebSocketManager: WebSocketManager
    
    @Published var latitude: Double = 0.0
    @Published var longitude: Double = 0.0
    @Published var altitude: Double = 0.0
    
    init(WebSocketManager: WebSocketManager) {
        self.WebSocketManager = WebSocketManager
        super.init()
        self.locationManager.delegate = self
        self.locationManager.desiredAccuracy = kCLLocationAccuracyBest
        self.requestAuthorization()
    }
    
    private func requestAuthorization() {
        if CLLocationManager.locationServicesEnabled() {
            switch locationManager.authorizationStatus {
            case .notDetermined:
                locationManager.requestWhenInUseAuthorization()
            case .restricted, .denied:
                print("Location access denied or restricted")
            case .authorizedWhenInUse, .authorizedAlways:
                startLocationUpdates()
            @unknown default:
                break
            }
        } else {
            print("Location services are not enabled")
        }
    }
    
    func startLocationUpdates() {
        locationManager.startUpdatingLocation()
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        DispatchQueue.main.async { [weak self] in
            self?.latitude = location.coordinate.latitude
            self?.longitude = location.coordinate.longitude
            self?.altitude = location.altitude
            
            //let json = self?.convertToJSON(latitude: self?.latitude ?? 0.0, longitude: self?.longitude ?? 0.0, altitude: self?.altitude ?? 0.0)
            //self?.webSocketManager.send(message: json ?? "")
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Error: \(error.localizedDescription)")
    }
}

