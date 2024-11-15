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
    //Object that manages sensors related to motion
    private var motionManager = CMMotionManager()
    
    @Published var webSocketManager: WebSocketManager
    
       //Acc Variables Data
       @Published var accX: Double = 0.0
       @Published var accY: Double = 0.0
       @Published var accZ: Double = 0.0
       
       //Gyro Variables Data
       @Published var gyroX: Double = 0.0
       @Published var gyroY: Double = 0.0
       @Published var gyroZ: Double = 0.0
        
   init(webSocketManager: WebSocketManager) {
            self.webSocketManager = webSocketManager
   }
    
    //Checks is the device has accelerometer
    func checkStatus() {
        if !motionManager.isAccelerometerAvailable {
            print("The device doesn't have Accelerometer")
        }
        
        if !motionManager.isGyroAvailable {
            print("The device doesn't have Magnetometer")
        }
    }
    
    //Accelerometer Data
    func startAccelerometerUpdates() {
        if motionManager.isAccelerometerAvailable {
            motionManager.accelerometerUpdateInterval = 1.0 / 100.0  // 100 Hz
            motionManager.startAccelerometerUpdates(to: OperationQueue.main) { (data, error) in
                if let accData = data {
                    // A aceleracao esta em Gs. 1G = 9.80665 m/s.^2
                    self.accX = (accData.acceleration.x * 9.80665)
                    self.accY = (accData.acceleration.y * 9.80665)
                    self.accZ = (accData.acceleration.z * 9.80665)
                    
                    let json = self.convertToJSON(accX: self.accX, accY: self.accY, accZ: self.accZ, gyroX: self.gyroX, gyroY: self.gyroY, gyroZ: self.gyroZ)
                    self.webSocketManager.send(message: json)
                    
                    /*print("ACELEROMETER DATA: \n")
                    print("X axis:  \(self.x) \n")
                    print("Y axis:  \(self.y) \n")
                    print("Z axis:  \(self.z) \n")*/
                } else {
                    print("Error: \(String(describing: error?.localizedDescription))")
                }
            }
        } else {
            print("Accelerometer is not available")
        }
        
        //Start Gyroscope Updates
        if motionManager.isGyroAvailable {
            motionManager.gyroUpdateInterval = 1.0 / 100.0  // 100 Hz
            motionManager.startGyroUpdates(to: OperationQueue.main) { (data, error) in
                if let gyroData = data  {
                    self.gyroX = gyroData.rotationRate.x
                    self.gyroY = gyroData.rotationRate.y
                    self.gyroZ = gyroData.rotationRate.z
                    
                    /*print("GYROSCOPE DATA: \n")
                     print("X axis:  \(self.x) \n")
                     print("Y axis:  \(self.y) \n")
                     print("Z axis:  \(self.z) \n")*/
                } else {
                    print("Error: \(String(describing: error?.localizedDescription))")
                }
            }
        } else {
            print("Gyroscope is not available")
        }
    }
    
    private func convertToJSON(accX: Double, accY: Double, accZ: Double, gyroX: Double, gyroY: Double, gyroZ: Double) -> String {
         let timestamp = Date().timeIntervalSince1970
         let sec = Int(timestamp)
         let nsec = Int((timestamp - Double(sec)) * 1_000_000_000)
         
         let json: [String: Any] = [
             "op": "publish",
             "topic": "/imu/accgyro",
             "msg": [
                 "header": [
                     "frame_id": "imu_link",
                     "stamp": [
                         "sec": sec,
                         "nsec": nsec
                     ]
                 ],
                 "orientation": [
                     "x": 0,
                     "y": 0,
                     "z": 0,
                     "w": 1
                 ],
                 "orientation_covariance": [-1,0,0,0,0,0,0,0,0],
                 "angular_velocity": [
                     "x": gyroX,
                     "y": gyroY,
                     "z": gyroZ
                 ],
                 "angular_velocity_covariance": [-1,0,0,0,0,0,0,0,0],
                 "linear_acceleration": [
                     "x": accX,
                     "y": accY,
                     "z": accZ
                 ],
                 "linear_acceleration_covariance": [-1,0,0,0,0,0,0,0,0]
             ]
         ]
         
         if let jsonData = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted) {
             return String(data: jsonData, encoding: .utf8) ?? "{}"
         } else {
             return "{}"
         }
     }
    
    /*private func saveToFile(json: String) {
        let appName = Bundle.main.infoDictionary![kCFBundleNameKey as String] as! String
        let fileName = "accelerometer_data.json"
        
        if let documentDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let appDirectory = documentDirectory.appendingPathComponent(appName)
            let dataDirectory = appDirectory.appendingPathComponent("acc_data")
            
            // Print paths for debugging
            //print("Document Directory: \(documentDirectory.path)")
            //print("App Directory: \(appDirectory.path)")
            //print("Data Directory: \(dataDirectory.path)")
            
            // Create app directory and data directory if they don't exist
            do {
                try FileManager.default.createDirectory(at: appDirectory, withIntermediateDirectories: true, attributes: nil)
                try FileManager.default.createDirectory(at: dataDirectory, withIntermediateDirectories: true, attributes: nil)
                print("Directories created successfully")
            } catch {
                print("Failed to create directory: \(error.localizedDescription)")
                return
            }
            
            let fileURL = dataDirectory.appendingPathComponent(fileName)
            do {
                // Append the JSON string to the file, if it exists. Otherwise, create a new file.
                if FileManager.default.fileExists(atPath: fileURL.path) {
                    if let fileHandle = try? FileHandle(forWritingTo: fileURL) {
                        fileHandle.seekToEndOfFile()
                        if let jsonData = json.data(using: .utf8) {
                            fileHandle.write(jsonData)
                            fileHandle.write("\n".data(using: .utf8)!) // Add newline for readability
                        }
                        fileHandle.closeFile()
                    }
                } else {
                    try json.write(to: fileURL, atomically: true, encoding: .utf8)
                }
                print("Data saved to file: \(fileURL.path)")
            } catch {
                print("Failed to write JSON data to file: \(error.localizedDescription)")
            }
        } else {
            print("Failed to find document directory")
        }
    }*/
}



