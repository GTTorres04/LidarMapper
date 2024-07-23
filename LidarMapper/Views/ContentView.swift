//
//  ContentView.swift
//  LidarMapper
//
//  Created by Forestry Robotics UC on 22/07/2024.
//

import SwiftUI
import CoreMotion


struct ContentView: View {
    var body: some View {
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundStyle(.tint)
                Text("Hello, world!")
        }
        .padding()
        .onAppear {
            let acc = Accelerometer()
            startTimer()
            acc.checkStatus()
            acc.startAccelerometerUpdates()
            let mag = Magnetometer()
            mag.checkStatus()
            mag.startMagnetometerUpdates()
        }
    }
}


    #Preview {
        ContentView()
    }

