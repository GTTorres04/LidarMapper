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
        
    var lastFrameTime: CFAbsoluteTime = 0
    let frameInterval: CFAbsoluteTime = 1 // 1 frame per second
    //Measuring the time each function takes to execute
    
    //captureOutput func is the one that takes more time to execute.
    
    init(webSocketManager: WebSocketManager) {
        self.webSocketManager = webSocketManager
        super.init()
        
        Task {
            await configureSession()
            await startSession()
        }
    }
    
    private func configureSession() async {
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
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
        let endTime = CFAbsoluteTimeGetCurrent()
        // Print the execution time
        let executionTime = endTime - startTime
        print("Execution time for configureSession: \(executionTime) seconds")
        
    }
    
    
    private func startSession() async {
        let startTime = CFAbsoluteTimeGetCurrent()
        captureSession.startRunning()
        let endTime = CFAbsoluteTimeGetCurrent()
        let executionTime = endTime - startTime
        print("Execution time for startSession: \(executionTime) seconds")
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
        let startTime = CFAbsoluteTimeGetCurrent()
        
        let width = cgImage.width
        let height = cgImage.height
        let bytesPerRow = width  // RGBA format: 4 bytes per pixel
        let totalBytes = bytesPerRow * height
        
        // Reuse the same buffer instead of allocating new memory each time
        var pixelData = Data(count: totalBytes)
        
        // Ensure correct color space (RGB)
        let colorSpace = G
        
        // Perform pixel buffer conversion with correct bitmap info
        pixelData.withUnsafeMutableBytes { ptr in
            guard let context = CGContext(data: ptr.baseAddress,
                                          width: width,
                                          height: height,
                                          bitsPerComponent: 8,
                                          bytesPerRow: bytesPerRow,
                                          space: colorSpace,
                                          bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue).rawValue) else {
                print("Error: Unable to create bitmap context")
                return
            }
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: CGFloat(width), height: CGFloat(height)))
        }
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let executionTime = endTime - startTime
        print("Execution time for cgImageToData: \(executionTime) seconds")
        
        return pixelData
    }
    
    private func convertToJSON(imageData: Data, height: Int, width: Int, encoding: String, step: Int) -> String {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        let timestamp = Date().timeIntervalSince1970
        let sec = Int(timestamp)
        let nsec = Int((timestamp - Double(sec)) * 1_000_000_000)
        let image_array = [UInt8](imageData)
        
        /* if let maxValue = image_array.max() {
         print("Max byte value in image data: \(maxValue)")
         } else {
         print("Error: image array is empty.")
         }*/
        //print("Image data byte count: \(image_array.count)")
        
        
        //print(image_array.count)
        
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
        let endTime = CFAbsoluteTimeGetCurrent()
        let executionTime = endTime - startTime
        print("Execution time for convertToJSON: \(executionTime) seconds")
        
        if let jsonData = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted) {
            return String(data: jsonData, encoding: .utf8) ?? "{}"
        } else {
            return "{}"
        }
    }
}

    var lastFrameTime: CFAbsoluteTime = 0
    let frameInterval: CFAbsoluteTime = 1 // 1 frame per second

extension Camera: AVCaptureVideoDataOutputSampleBufferDelegate {
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        
        
        let currentTime = CFAbsoluteTimeGetCurrent()
        
        // Skip frames if they are too close in time
        guard currentTime - lastFrameTime >= frameInterval else {
            return
        }
        lastFrameTime = currentTime
        
        // Existing processing logic...
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            print("Error: Could not get image buffer from sampleBuffer")
            return
        }
        
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        
        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else {
            print("Error: Could not get base address of pixel buffer")
            CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly)
            return
        }
        
        let imageData = Data(bytes: baseAddress, count: bytesPerRow * height)
        CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly)
        
        DispatchQueue.global(qos: .background).async { [weak self] in
            let encoding = "rgba8"
            let step = width * 4
            
            let json = self?.convertToJSON(imageData: imageData, height: height, width: width, encoding: encoding, step: step)
            
            DispatchQueue.main.async {
                if let json = json {
                    self?.webSocketManager.send(message: json)
                } else {
                    print("Error: JSON is nil")
                }
            }
        }
    }
}


