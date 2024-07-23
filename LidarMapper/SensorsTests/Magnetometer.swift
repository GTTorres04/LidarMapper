//
//  Magnetometer.swift
//  LidarMapper
//
//  Created by Forestry Robotics UC on 23/07/2024.
//

import SwiftUI
import CoreMotion

class Magnetometer {
    //Objeto que gere sensores relacionados a movimento.
    let motionManager = CMMotionManager()
    
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
                if data != nil  {
                    let magData = CMCalibratedMagneticField() //Campo magnetico calibrado
                    let x = magData.field.x
                    let y = magData.field.y
                    let z = magData.field.z
                    
                    print("MAGNETOMETER DATA: \n")
                    print("X axis:  \(x) \n")
                    print("Y axis:  \(y) \n")
                    print("Z axis:  \(z) \n")
                } else {
                    print("Error: \(String(describing: error?.localizedDescription))")
                }
            }
        } else {
            print("Magnetometer is not available")
        }
    }
}

