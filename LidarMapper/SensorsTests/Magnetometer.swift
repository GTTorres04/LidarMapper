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
    //Object that manages sensors related to motion
    private var motionManager = CMMotionManager()

    @Published var x: Double = 0.0
    @Published var y: Double = 0.0
    @Published var z: Double = 0.0
    
    //Checks if the device has magnetometer
    func checkStatus() {
        if !motionManager.isDeviceMotionAvailable {
            print("The device doesn't have Magnetometer")
        }
    }
    
    //Magnetometer Data
    func startMagnetometerUpdates() {
        if motionManager.isDeviceMotionAvailable {
            motionManager.deviceMotionUpdateInterval = 1.0 / 100.0  // 100 Hz
            motionManager.startDeviceMotionUpdates(using:.xMagneticNorthZVertical, to: OperationQueue.main) { (motion, error) in
                if let deviceMotion = motion  {
                    let magData = deviceMotion.magneticField.field
                    self.x = (magData.x * 10*exp(-6))
                    self.y = (magData.y * 10*exp(-6))
                    self.z = (magData.z * 10*exp(-6))
                    
                   /* print("MAGNETOMETER DATA: \n")
                    print("X axis:  \(self.x) \n")
                    print("Y axis:  \(self.y) \n")
                    print("Z axis:  \(self.z) \n")*/
                } else {
                    print("Error: \(String(describing: error?.localizedDescription))")
                }
            }
        } else {
            print("Magnetometer is not available")
        } 
    }
} 

