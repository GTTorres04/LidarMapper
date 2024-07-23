//
//  ContentView.swift
//  LidarMapper
//
//  Created by Forestry Robotics UC on 22/07/2024.
//

import SwiftUI
import CoreMotion
import Combine


struct ContentView: View {
    @StateObject private var timerManager = TimerManager()
    @StateObject private var acc = Accelerometer()
    @StateObject private var mag = Magnetometer()
    var body: some View {
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundStyle(.tint)
                Text("Hello, world!")
        }
        .padding()
        .onAppear {
                timerManager.startTimer()
                acc.checkStatus()
                acc.startAccelerometerUpdates()
                mag.checkStatus()
                mag.startMagnetometerUpdates()
            }
        }
    }


    #Preview {
        ContentView()
    }

