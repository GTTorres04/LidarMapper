//
//  ViewModel.swift
//  LidarMapper
//
//  Created by Forestry Robotics UC on 05/09/2024.
//
import Foundation
import Combine
import CoreImage

class ViewModel: ObservableObject {
    @Published var currentFrame: CGImage?  // This property holds the current frame for display

    private let camera = Camera(webSocketManager: WebSocketManager())  // Initialize your Camera object

    init() {
        // Start handling camera previews as soon as ViewModel is initialized
        Task {
            await handleCameraPreviews()
        }
    }

    // Function to handle incoming camera frames
    func handleCameraPreviews() async {
        // Start receiving frames from the Camera's `previewStream`
        for await image in camera.previewStream {
            // Update the current frame on the main thread to refresh the UI
            await MainActor.run {
                self.currentFrame = image
            }
        }
    }

    // You can add more functionality to control the camera (start/stop session etc.)
    func startCameraSession() async {
        await camera.startSession()
    }
}


