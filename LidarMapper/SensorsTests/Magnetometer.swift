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
    private var deviceMotionManager = CMMotionManager()
    
    
    @Published var x: Double = 0.0
    @Published var y: Double = 0.0
    @Published var z: Double = 0.0
    
    //Verifica se o dispositivo possui magnetometro
    func checkStatus() {
        if !motionManager.isMagnetometerAvailable {
            print("The device doesn't have Magnetometer")
        }
    }
    
    //Dados do Magnetometro
    func startMagnetometerUpdates() {
        if motionManager.isMagnetometerAvailable {
            motionManager.magnetometerUpdateInterval = 1.0 / 100.0  // 100 Hz
            motionManager.startMagnetometerUpdates(to: OperationQueue.main) { (data, error) in
                if let deviceMotion = data  {
                    let magneticField = deviceMotion.magneticField
                    self.x = magneticField.x
                    self.y = magneticField.y
                    self.z = magneticField.z
                    
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
}

