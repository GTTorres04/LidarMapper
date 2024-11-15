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
import AVFoundation

struct ContentView: View {
    @StateObject var timerManager = TimerManager()
    @StateObject var webSocket = WebSocketManager()
    @StateObject private var acc = Accelerometer(webSocketManager: WebSocketManager())
    @StateObject private var mag = Magnetometer(webSocketManager: WebSocketManager())
    @StateObject var gyro = Gyroscope()
    @StateObject var gps = GPS(WebSocketManager: WebSocketManager())
    
    @State  var viewModel = ViewModel()
    @StateObject var camera = Camera(webSocketManager: WebSocketManager())
    @StateObject var cameraInfo = CameraInfo()
    @StateObject var pointCloudData = PointCloudData()
    
    
    // State to toggle between views
    //@State private var showCameraView = true
    
    var body: some View {
            /*VStack {
                // Button to toggle views
                Button(action: {
                    showCameraView.toggle()
                }) {
                    Text(showCameraView ? "Show Data" : "Show Camera")
                        .font(.headline)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .padding()

                // Conditional View Display
                if showCameraView {
                    // Show CameraView when showCameraView is true
                    CameraView(image: $viewModel.currentFrame)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {*/
                    // Show Data view when showCameraView is false
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
                            Text("Latitude: \(gps.latitude)")
                            Text("Longitude: \(gps.longitude)")
                            Text("Altitude: \(gps.altitude)")
                            Text("Status: \(gps.status)")
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
                        gps.startLocationUpdates()
                        webSocket.receive()
                    }
                }
            }
            //.padding()

#Preview {
    ContentView()
}



