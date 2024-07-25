//
//  ContentView.swift
//  LidarMapper
//
//  Created by Forestry Robotics UC on 22/07/2024.
//

import SwiftUI
import CoreMotion
import Combine
import Foundation

struct ContentView: View {
    @StateObject var timerManager = TimerManager()
    @StateObject private var acc = Accelerometer()
    @StateObject private var mag = Magnetometer()
    @StateObject private var gyro = Gyroscope()
    
    var body: some View {
        VStack {
            HStack {
                Text("Current UNIX Timestamp: \(timerManager.currentUnixTimestamp)")
                    .font(.title3)
                    .padding()
                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack {
                Text("ACCELEROMETER DATA: ")
                    .font(.title2)
                Text("X: \(acc.x)")
                Text("Y: \(acc.y)")
                Text("Z: \(acc.z)")
                Text("\n")
                
                Text("MAGNETOMETER DATA: ")
                    .font(.title2)
                Text("X: \(mag.x)")
                Text("Y: \(mag.y)")
                Text("Z: \(mag.z)")
                Text("\n")
                
                Text("GYROSCOPE DATA: ")
                    .font(.title2)
                Text("X: \(gyro.x)")
                Text("Y: \(gyro.y)")
                Text("Z: \(gyro.z)")
            }
            .padding()
        }
        .padding()
        .onAppear {
            acc.checkStatus()
            acc.startAccelerometerUpdates()
            mag.checkStatus()
            mag.startMagnetometerUpdates()
            gyro.checkStatus()
            gyro.startGyroUpdates()
        }
    }
}

#Preview {
    ContentView()
}



