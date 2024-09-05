//
//  Camera.swift
//  LidarMapper
//
//  Created by Forestry Robotics UC on 05/09/2024.
//

import Foundation
import AVFoundation

class Camera: NSObject {
    
    private let captureSession = AVCaptureSession()
    
    private var deviceInput: AVCaptureDeviceInput?
    
    private var videoOutput: AVCaptureVideoDataOutput?
    
    private let systemPreferredCamera = AVCaptureDevice.default(for: .video)
    
    private var sessionQueue = DispatchQueue(label: "video.preview.session")
    
    
}
