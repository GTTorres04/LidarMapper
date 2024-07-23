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
            checkStatus()
            startAccelerometerUpdates()
            startTimer()
        }
    }
}


    #Preview {
        ContentView()
    }

