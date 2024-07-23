//
//  File.swift
//  LidarMapper
//
//  Created by Forestry Robotics UC on 22/07/2024.
//

import SwiftUI
import CoreMotion


//Objeto que gere sensores relacionados a movimento.
let motionManager = CMMotionManager()

var elapsedTime: String = "00:00:00"
var startTime: Date = Date()
var timer: Timer? = nil

//Timer 
func startTimer() {
    startTime = Date()
    timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
        let now = Date()
        let elapsed = now.timeIntervalSince(startTime)
        let hours = Int(elapsed) / 3600
        let minutes = (Int(elapsed) % 3600) / 60
        let seconds = Int(elapsed) % 60
        elapsedTime = String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
}

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
                let x = (accData.acceleration.x * 9.80665)
                let y = (accData.acceleration.y * 9.80665)
                let z = (accData.acceleration.z * 9.80665)
                
                print("ACELEROMETER DATA: \n")
                print("Elapsed Time: \(elapsedTime) \n")
                print("X axis:  \(x) \n")
                print("Y axis:  \(y) \n")
                print("Z axis:  \(z) \n")
            } else {
                print("Error: \(String(describing: error?.localizedDescription))")
            }
        }
    } else {
        print("Accelerometer is not available")
    }
}



