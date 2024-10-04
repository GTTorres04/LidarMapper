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
            if let cgImage = viewModel.currentFrame {
                // Convert CGImage to UIImage for SwiftUI
                let uiImage = UIImage(cgImage: cgImage)
                
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
                    .ignoresSafeArea(edges: .all)
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



