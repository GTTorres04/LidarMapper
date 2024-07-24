//
//  File.swift
//  LidarMapper
//
//  Created by Forestry Robotics UC on 22/07/2024.
//

import SwiftUI
import CoreMotion
import Foundation
import Combine


class Accelerometer: ObservableObject {
    //Objeto que gere sensores relacionados a movimento.
    private var motionManager = CMMotionManager()
    
    @Published var x: Double = 0.0
    @Published var y: Double = 0.0
    @Published var z: Double = 0.0
        
    //Verifica se o dispositivo possui acelerometro
    func checkStatus() {
        if !motionManager.isAccelerometerAvailable {
            print("The device doesn't have Accelerometer")
        }
    }
    
    //Dados do acelerometro
    func startAccelerometerUpdates() {
        if motionManager.isAccelerometerAvailable {
            motionManager.accelerometerUpdateInterval = 1.0 / 100.0  // 100 Hz
            motionManager.startAccelerometerUpdates(to: OperationQueue.main) { (data, error) in
                if let accData = data {
                    // A aceleracao esta em Gs. 1G = 9.80665 m/s.^2
                    self.x = (accData.acceleration.x * 9.80665)
                    self.y = (accData.acceleration.y * 9.80665)
                    self.z = (accData.acceleration.z * 9.80665)
                    
                    print("ACELEROMETER DATA: \n")
                    print("X axis:  \(self.x) \n")
                    print("Y axis:  \(self.y) \n")
                    print("Z axis:  \(self.z) \n")
                } else {
                    print("Error: \(String(describing: error?.localizedDescription))")
                }
            }
        } else {
            print("Accelerometer is not available")
        }
    }
}



