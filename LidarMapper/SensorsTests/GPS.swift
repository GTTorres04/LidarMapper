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

let STATUS_NO_FIX: Int = -1        // unable to fix position =0 OR ELSE
let STATUS_FIX: Int = 0            // unaugmented fix        >1
let STATUS_SBAS_FIX: Int = 1       // with satellite-based augmentation 0.1 - 1
let STATUS_GBAS_FIX: Int = 2       // with ground-based augmentation 0.00001-0.1

class GPS: NSObject, ObservableObject, CLLocationManagerDelegate {
    
    private var locationManager = CLLocationManager()
    
    @Published var WebSocketManager: WebSocketManager
    
    @Published var latitude: Double = 0.0
    @Published var longitude: Double = 0.0
    @Published var altitude: Double = 0.0
    @Published var status: Int = STATUS_NO_FIX
    
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
        guard let location = locations.last else {
            self.status = STATUS_NO_FIX
            return
        }
        
        DispatchQueue.main.async { [weak self] in
            self?.latitude = location.coordinate.latitude
            self?.longitude = location.coordinate.longitude
            self?.altitude = location.altitude
            
            // Update status based on horizontal accuracy
            //TODO: Isto não está bem feito. No futuro falar com o Mário
            if (location.horizontalAccuracy > 0.0001 && location.horizontalAccuracy <= 0.1) || (location.verticalAccuracy > 0.0001 && location.verticalAccuracy <= 0.1) {
                self?.status = STATUS_GBAS_FIX
            } else if (location.horizontalAccuracy > 0.1 && location.horizontalAccuracy <= 1) || (location.verticalAccuracy > 0.1 && location.verticalAccuracy <= 1) {
                self?.status = STATUS_SBAS_FIX
            } else if (location.horizontalAccuracy > 1) || (location.verticalAccuracy > 1) {
                self?.status = STATUS_FIX
            } else if (location.horizontalAccuracy == 0) || (location.verticalAccuracy == 0) {
                self?.status = STATUS_NO_FIX
            }else {
                self?.status = STATUS_NO_FIX
            }
            
            
            
            //let json = self?.convertToJSON(latitude: self?.latitude ?? 0.0, longitude: self?.longitude ?? 0.0, altitude: self?.altitude ?? 0.0)
            //self?.webSocketManager.send(message: json ?? "")
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Error: \(error.localizedDescription)")
    }
    
    private func convertToJSON(latitude: Double, longitude: Double, altitude: Double, status: Int) -> String {
        let timestamp = Date().timeIntervalSince1970
        let sec = Int(timestamp)
        let nsec = Int((timestamp - Double(sec)) * 1_000_000_000)
        
        let json: [String: Any] = [
            "op": "publish",
            "topic": "/imu/NavSatFix",
            "msg": [
                "header": [
                    "frame_id": "gps_link"
                ],
                "status": [
                    "status": status,
                    "service": 
                ],
                "latitude": latitude
                    "longitude": longitude,
                "altitude": altitude,
                "position_covariance": [-1,0,0,0,0,0,0,0,0],
                "position_covariance_type": 1
            ]
        ]
        
        if let jsonData = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted) {
            return String(data: jsonData, encoding: .utf8) ?? "{}"
        } else {
            return "{}"
        }
    }
}


