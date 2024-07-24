//
//  TimerManager.swift
//  LidarMapper
//
//  Created by Forestry Robotics UC on 23/07/2024.
//

import SwiftUI
import Foundation
import CoreMotion
import Combine

class TimerManager: ObservableObject {
    @Published var currentUnixTimestamp: Int
    
    @Published var timer: Timer?
    
    init() {
        // Initialize the timestamp
        self.currentUnixTimestamp = Int(Date().timeIntervalSince1970)
        
        // Start a timer to update the timestamp every second
        self.startUpdatingTimestamp()
    }
    
    func startUpdatingTimestamp() {
        // Update timestamp every second
        timer = Timer.scheduledTimer(withTimeInterval: (1.0 / 100.0), repeats: true) { [weak self] _ in
            self?.updateTimestamp()
        }
    }
    
    func updateTimestamp() {
        self.currentUnixTimestamp = Int(Date().timeIntervalSince1970)
    }
}

