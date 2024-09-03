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
    @StateObject var webSocket = WebSocketManager()
    @StateObject private var acc = Accelerometer(webSocketManager: WebSocketManager())
    @StateObject private var mag = Magnetometer(webSocketManager: WebSocketManager())
    @StateObject var gyro = Gyroscope()
    @StateObject var gps = GPS(WebSocketManager: WebSocketManager())
    
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
                Text("X: \(acc.accX)")
                Text("Y: \(acc.accY)")
                Text("Z: \(acc.accZ)")
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
                Text("\n")
                
                Text("GPS DATA: ")
                    .font(.title2)
                Text("X: \(gps.latitude)")
                Text("Y: \(gps.longitude)")
                Text("Z: \(gps.altitude)")
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
            
            webSocket.receive()
        }
    }
}

#Preview {
    ContentView()
}



