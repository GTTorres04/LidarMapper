//
//  Magnetometer.swift
//  LidarMapper
//
//  Created by Forestry Robotics UC on 23/07/2024.
//

import SwiftUI
import CoreMotion
import Foundation

class Magnetometer: ObservableObject {
    //Objeto que gere sensores relacionados a movimento.
    private var motionManager = CMMotionManager()

    @Published var x: Double = 0.0
    @Published var y: Double = 0.0
    @Published var z: Double = 0.0
    
    //Verifica se o dispositivo possui magnetometro
    func checkStatus() {
        if !motionManager.isDeviceMotionAvailable {
            print("The device doesn't have Magnetometer")
        }
    }
    
    //Dados do Magnetometro
    func startMagnetometerUpdates() {
        if motionManager.isDeviceMotionAvailable {
            motionManager.deviceMotionUpdateInterval = 1.0 / 100.0  // 100 Hz
            motionManager.startDeviceMotionUpdates(using:.xTrueNorthZVertical, to: OperationQueue.main) { (motion, error) in
                if let deviceMotion = motion  {
                    let magData = deviceMotion.magneticField.field
                    self.x = magData.x
                    self.y = magData.y
                    self.z = magData.z
                    self.x = self.mapTo360Degrees(value: self.x)
                    self.y = self.mapTo360Degrees(value: self.y)
                    self.z = self.mapTo360Degrees(value: self.z)
                    
                    print("MAGNETOMETER DATA: \n")
                    print("X axis:  \(self.x) \n")
                    print("Y axis:  \(self.y) \n")
                    print("Z axis:  \(self.z) \n")
                } else {
                    print("Error: \(String(describing: error?.localizedDescription))")
                }
            }
        } else {
            print("Magnetometer is not available")
        } 
    }
    
    func mapTo360Degrees(value: Double) -> Double {
        let degrees = value.truncatingRemainder(dividingBy: 360)
        return degrees >= 0 ? degrees : degrees + 360
    }
    
}

