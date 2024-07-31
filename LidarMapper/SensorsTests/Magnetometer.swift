//
//  Magnetometer.swift
//  LidarMapper
//
//  Created by Forestry Robotics UC on 23/07/2024.
//
import SwiftUI
import CoreMotion
import Foundation
import Combine

class Magnetometer: ObservableObject {
    private var motionManager = CMMotionManager()
    @Published var webSocketManager: WebSocketManager

    @Published var x: Double = 0.0
    @Published var y: Double = 0.0
    @Published var z: Double = 0.0
    
    init(webSocketManager: WebSocketManager) {
        self.webSocketManager = webSocketManager
    }
    
    func checkStatus() {
        if !motionManager.isDeviceMotionAvailable {
            print("The device doesn't have Magnetometer")
        }
    }
    
    func startMagnetometerUpdates() {
        if motionManager.isDeviceMotionAvailable {
            motionManager.deviceMotionUpdateInterval = 1.0 / 100.0  // 100 Hz
            motionManager.startDeviceMotionUpdates(using:.xMagneticNorthZVertical, to: OperationQueue.main) { (motion, error) in
                if let deviceMotion = motion  {
                    let magData = deviceMotion.magneticField.field
                    self.x = magData.x * 10 * exp(-6)
                    self.y = magData.y * 10 * exp(-6)
                    self.z = magData.z * 10 * exp(-6)
                    
                    let json = self.convertToJSON(x: self.x, y: self.y, z: self.z)
                    self.webSocketManager.send(message: json)
                } else {
                    print("Error: \(String(describing: error?.localizedDescription))")
                }
            }
        } else {
            print("Magnetometer is not available")
        }
    }
    
    private func convertToJSON(x: Double, y: Double, z: Double) -> String {
        let timestamp = Date().timeIntervalSince1970
        let sec = Int(timestamp)
        let nsec = Int((timestamp - Double(sec)) * 1_000_000_000)

        let json: [String: Any] = [
            "op": "publish",
            "topic": "/imu/mag",
            "msg": [
                "header": [
                    "frame_id": "imu_link",
                    "stamp": [
                        "sec": sec,
                        "nsec": nsec
                    ]
                ],
                "magnetic_field": [
                    "x": x,
                    "y": y,
                    "z": z
                ],
                "magnetic_field_covariance": [-1,0,0,0,0,0,0,0,0]
            ]
        ]

        if let jsonData = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted) {
            return String(data: jsonData, encoding: .utf8) ?? "{}"
        } else {
            return "{}"
        }
    }
}


