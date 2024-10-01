//
//  ViewModel.swift
//  LidarMapper
//
//  Created by Forestry Robotics UC on 05/09/2024.
//
import Foundation
import Combine
import CoreImage

class ViewModel: ObservableObject {  // Must conform to ObservableObject
    @Published var currentFrame: CGImage?  // Published stored property
    
    let camera = Camera(webSocketManager: WebSocketManager())
    
    init() {
        Task {
            await handleCameraPreviews()
        }
    }
    
    // Handles camera previews
    func handleCameraPreviews() async {
        for await image in camera.previewStream {
            //print("Received a new frame")
            Task { @MainActor in
                self.currentFrame = image  // This updates the UI
            }
        }
    }
}

