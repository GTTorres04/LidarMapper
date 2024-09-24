//
//  CameraView.swift
//  LidarMapper
//
//  Created by Forestry Robotics UC on 05/09/2024.
//

import SwiftUI
import AVFoundation
import Foundation

struct CameraView: View {
    @StateObject var viewModel = ViewModel()  // Conforms to ObservableObject

    var body: some View {
        GeometryReader { geometry in
            if let image = viewModel.currentFrame {
                Image(image, scale: 1, label: Text("Camera Feed"))
                    .resizable()
                    .scaledToFit()
                    .frame(width: geometry.size.width, height: geometry.size.height)
            } else {
                Text("No camera feed")
                    .frame(width: geometry.size.width, height: geometry.size.height)
            }
        }
        .onAppear {
            Task {
                await viewModel.handleCameraPreviews()  // Starts handling camera previews
            }
        }
    }
}



