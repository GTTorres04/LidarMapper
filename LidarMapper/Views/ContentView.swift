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
    
    var body: some View {
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
        }
        .padding()
        .onAppear {
            timerManager.startTimer()
            acc.checkStatus()
            acc.startAccelerometerUpdates()
        }
        .onAppear {
            mag.checkStatus()
            mag.startMagnetometerUpdates()
        }
    }
}

#Preview {
    ContentView()
}



