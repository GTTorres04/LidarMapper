//
//  Camera.swift
//  LidarMapper
//
//  Created by Forestry Robotics UC on 05/09/2024.
//

import Foundation
import AVFoundation
import UIKit

class Camera: NSObject, ObservableObject {
    
    private let captureSession = AVCaptureSession()
    private var deviceInput: AVCaptureDeviceInput?
    private var videoOutput: AVCaptureVideoDataOutput?
    private let systemPreferredCamera = AVCaptureDevice.default(for: .video)
    private var sessionQueue = DispatchQueue(label: "video.preview.session")
    var G: CGColorSpace = CGColorSpaceCreateDeviceRGB()
    var j: CGBitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
    
    @Published var webSocketManager: WebSocketManager
    @Published var image: CGImage?
    
    init(webSocketManager: WebSocketManager) {
        self.webSocketManager = webSocketManager
        super.init()
        
        Task {
            await configureSession()
            await startSession()
        }
    }
    
    private func configureSession() async {
        guard let systemPreferredCamera,
              let deviceInput = try? AVCaptureDeviceInput(device: systemPreferredCamera)
        else { return }
        
        captureSession.beginConfiguration()
        
        defer {
            captureSession.commitConfiguration()
        }
        
        // Set session preset to a format suitable for your use case (e.g., high or medium)
        captureSession.sessionPreset = .high
        
        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.setSampleBufferDelegate(self, queue: sessionQueue)
        
        if captureSession.canAddInput(deviceInput) && captureSession.canAddOutput(videoOutput) {
            captureSession.addInput(deviceInput)
            captureSession.addOutput(videoOutput)
        } else {
            print("Error: Unable to add input/output to capture session.")
        }
    }
    
    
    private func startSession() async {
        captureSession.startRunning()
    }
    
    private var addToPreviewStream: ((CGImage) -> Void)?
    
    lazy var previewStream: AsyncStream<CGImage> = {
        AsyncStream { continuation in
            addToPreviewStream = { cgImage in
                continuation.yield(cgImage)
            }
        }
    }()
    
    func cgImageToData(_ cgImage: CGImage) -> Data? {
        // Create a UIImage from the CGImage
        let image = UIImage(cgImage: cgImage)
        
        // Get the CGImage reference from UIImage
        guard let imageRef = image.cgImage else {
            print("Error: Unable to get CGImage from UIImage")
            return nil
        }
        
        // Get image dimensions
        let width = imageRef.width
        let height = imageRef.height
        
        // Define the color space
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        
        // Calculate the number of bytes per row (4 bytes per pixel for RGBA)
        let bytesPerRow = width * 4
        
        // Define the number of bits per color component (8 bits for RGBA)
        let bitsPerComponent: UInt = 8
        
        // Allocate memory for the pixel data (width * height * 4 bytes for RGBA)
        guard let pixelData = calloc(width * height * 4, MemoryLayout<UInt8>.size) else {
            print("Error: Unable to allocate memory for pixel data")
            return nil
        }
        
        do {
            free(pixelData)  // Free the memory when done
        }
        
        // Create the bitmap context with the pixel data buffer
        guard let context = CGContext(data: pixelData,
                                      width: width,
                                      height: height,
                                      bitsPerComponent: Int(bitsPerComponent),
                                      bytesPerRow: bytesPerRow,
                                      space: colorSpace,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            print("Error: Unable to create bitmap context")
            return nil
        }
        // Convert the pixel data to a Data object
        let data = Data(bytes: pixelData, count: width * height * 4)
        return (context as! Data)
    }
    
    private func convertToJSON(imageData: Data, height: Int, width: Int, encoding: String, step: Int) -> String {
        let timestamp = Date().timeIntervalSince1970
        let sec = Int(timestamp)
        let nsec = Int((timestamp - Double(sec)) * 1_000_000_000)
        let image_array = [UInt8](imageData)
        
        print(image_array.max())
        print(image_array.count)
        
        let json: [String: Any] = [
            "op": "publish",
            "topic": "/camera",
            "msg": [
                "header": [
                    "frame_id": "camera",
                    "stamp": [
                        "sec": sec,
                        "nsec": nsec
                    ]
                ],
                "height": height,
                "width": width,
                "encoding": encoding,
                "is_bigendian": 0,
                "step": step,
                "data": image_array
            ]
        ]
        
        if let jsonData = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted) {
            return String(data: jsonData, encoding: .utf8) ?? "{}"
        } else {
            return "{}"
        }
    }
}

extension Camera: AVCaptureVideoDataOutputSampleBufferDelegate {
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        print("Frame captured!")
        
        // Check if we can convert to CGImage
        guard let cgImage = sampleBuffer.cgImage else {
            print("Error converting CMSampleBuffer to CGImage")
            return
        }
        
        // For debugging purposes, let's log the width and height
        print("Image captured: \(cgImage.width) x \(cgImage.height)")
        
        // Dispatch the captured image to the main thread for the preview stream
        DispatchQueue.main.async {
            self.addToPreviewStream?(cgImage)
        }
        
        // Send the image to WebSocket (optional, if it's for ROS)
        if let imageData = cgImageToData(cgImage) {
            let width = cgImage.width
            let height = cgImage.height
            let encoding = "rgb16"
            let step = width * 4 // Assuming 4 bytes per pixel
            
            let json = self.convertToJSON(imageData: imageData, height: height, width: width, encoding: encoding, step: step)
            self.webSocketManager.send(message: json)
        } else {
            print("Error converting CGImage to Data")
        }
    }
}



