//
//  clearConsole.swift
//  LidarMapper
//
//  Created by Forestry Robotics UC on 24/07/2024.
//

import Foundation
import SwiftUI

class clearConsole: ObservableObject {
    func clearConsole() {
        for _ in 0...100 {
            print("\n")
        }
    }
}

