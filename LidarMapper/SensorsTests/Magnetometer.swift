//
//  Magnetometer.swift
//  LidarMapper
//
//  Created by Forestry Robotics UC on 23/07/2024.
//

import SwiftUI
import CoreMotion

class Magnetometer {
    
    let motionManager = CMMotionManager()
    
    //Verifica se o dispositivo possui magnetometro
    func checkStatus() {
        if !motionManager.isMagnetometerAvailable {
            print("The device doesn't have Magnetometer")
        }
    }
    
    
    
}

