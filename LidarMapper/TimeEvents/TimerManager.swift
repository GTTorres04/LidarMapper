//
//  TimerManager.swift
//  LidarMapper
//
//  Created by Forestry Robotics UC on 23/07/2024.
//

import SwiftUI
import Foundation

class TimerManager: ObservableObject {
    @Published var elapsedTime: String = "00:00:00"
    private var startTime: Date = Date()
    private var timer: Timer? = nil
    
    //Timer
    func startTimer() {
        startTime = Date()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            let now = Date()
            let elapsed = now.timeIntervalSince(self.startTime)
            let hours = Int(elapsed) / 3600
            let minutes = (Int(elapsed) % 3600) / 60
            let seconds = Int(elapsed) % 60
            self.elapsedTime = String(format: "%02d:%02d:%02d", hours, minutes, seconds)
            print("Elapsed Time: \(self.elapsedTime) \n")
        }
    }
}
