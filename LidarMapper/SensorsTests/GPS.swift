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
    
    //gps coordinates
    @Published var latitude: Double = 0.0
    @Published var longitude: Double = 0.0
    @Published var altitude: Double = 0.0
    
    init(WebSocketManager: WebSocketManager) {
        self.WebSocketManager = WebSocketManager
        super.init()
        self.locationManager.delegate = self
        self.locationManager.desiredAccuracy = kCLLocationAccuracyBest
        self.locationManager.requestWhenInUseAuthorization()
        self.locationManager.startUpdatingLocation()
    }

    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.last {
            self.latitude = location.coordinate.latitude
            self.longitude = location.coordinate.longitude
            self.altitude = location.altitude
            
            /*let json = self.convertToJSON(latitude: self.latitude, longitude: self.longitude, altitude: self.altitude)
             self.WebSocketManager.send(message: json)*/
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Error: \(error.localizedDescription)")
    }
    
}


