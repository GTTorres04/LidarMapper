//
//  Gyroscope.swift
//  LidarMapper
//
//  Created by Forestry Robotics UC on 24/07/2024.
//

import SwiftUI
import CoreMotion
import Foundation
import Combine

class Gyroscope: ObservableObject {
    //Objeto que gere sensores relacionados a movimento.
    private var motionManager = CMMotionManager()
    
    @Published var x: Double = 0.0
    @Published var y: Double = 0.0
    @Published var z: Double = 0.0
    
    //Verifica se o dispositivo possui giroscopio
    func checkStatus() {
        if !motionManager.isGyroAvailable {
            print("The device doesn't have Magnetometer")
        }
    }
    
    //Dados do Magnetometro
    func startGyroUpdates() {
        if motionManager.isGyroAvailable {
            motionManager.gyroUpdateInterval = 1.0 / 100.0  // 100 Hz
            motionManager.startGyroUpdates(to: OperationQueue.main) { (data, error) in
                if let gyroData = data  {
                    self.x = gyroData.rotationRate.x
                    self.y = gyroData.rotationRate.y
                    self.z = gyroData.rotationRate.z
                    
                    print("GYROSCOPE DATA: \n")
                    print("X axis:  \(self.x) \n")
                    print("Y axis:  \(self.y) \n")
                    print("Z axis:  \(self.z) \n")
                } else {
                    print("Error: \(String(describing: error?.localizedDescription))")
                }
            }
        } else {
            print("Gyroscope is not available")
        }
    }
    
}

