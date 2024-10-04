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
    
    @Published var image: CGImage?
    var addToPreviewStream: ((CGImage) -> Void)?
    @Published var webSocketManager = WebSocketManager()
    
    var lastFrameTime: CFAbsoluteTime = 0
    let frameInterval: CFAbsoluteTime = 1.0 / 15.0 // 15 FPS

    init(webSocketManager: WebSocketManager) {
        super.init()
        self.webSocketManager = webSocketManager
        
        Task {
            await configureSession()
            await startSession()
        }
    }

    private func configureSession() async {
        guard let systemPreferredCamera,
              let deviceInput = try? AVCaptureDeviceInput(device: systemPreferredCamera) else { return }

        captureSession.beginConfiguration()
        
        defer {
            captureSession.commitConfiguration()
        }
        // Camera Resolution
        captureSession.sessionPreset = .medium
        
        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.setSampleBufferDelegate(self, queue: sessionQueue)

        if captureSession.canAddInput(deviceInput) && captureSession.canAddOutput(videoOutput) {
            captureSession.addInput(deviceInput)
            captureSession.addOutput(videoOutput)
        } else {
            print("Error: Unable to add input/output to capture session.")
        }
    }
    
    func startSession() async {
        captureSession.startRunning()
    }
    
    lazy var previewStream: AsyncStream<CGImage> = {
            AsyncStream { continuation in
                addToPreviewStream = { cgImage in
                    continuation.yield(cgImage)
                }
            }
        }()
    
    // Converting CMSampleBuffer to CGImage
    private func cgImageFromSampleBuffer(_ sampleBuffer: CMSampleBuffer) -> CGImage? {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            print("Error: Could not get image buffer from sampleBuffer")
            return nil
        }
        
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext()
        return context.createCGImage(ciImage, from: ciImage.extent)
    }
}


extension Camera: AVCaptureVideoDataOutputSampleBufferDelegate {
    
     func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        let currentTime = CFAbsoluteTimeGetCurrent()
        
        // Skip frames if they are too close in time
        guard currentTime - lastFrameTime >= frameInterval else {
            return
        }
        lastFrameTime = currentTime
        
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            print("Error getting pixel buffer from sampleBuffer")
            return
        }
        
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        
        // Process the image into CGImage
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext(options: nil)
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            print("Error creating CGImage")
            CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly)
            return
        }
        
        CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly)
        
        DispatchQueue.global(qos: .background).async {
            // This method should now be faster due to the above optimizations
            self.addToPreviewStream?(cgImage)
            
            // Optional: Compress and send over WebSocket
            if let imageData = self.cgImageToData(cgImage) {
                let width = cgImage.width
                let height = cgImage.height
                let encoding = "rgba8"
                let step = width * 4 // Assuming 4 bytes per pixel
                
                let json = self.convertToJSON(imageData: imageData, height: height, width: width, encoding: encoding, step: step)
                self.webSocketManager.send(message: json) // Send this in background to avoid blocking
            }
        }
    }

    
    private func cgImageToData(_ cgImage: CGImage) -> Data? {
        let width = cgImage.width
        let height = cgImage.height
        let bytesPerRow = width * 4 // Assuming 4 bytes per pixel
        let totalBytes = bytesPerRow * height
        
        var pixelData = Data(count: totalBytes)
        pixelData.withUnsafeMutableBytes { ptr in
            guard let context = CGContext(data: ptr.baseAddress,
                                          width: width,
                                          height: height,
                                          bitsPerComponent: 8,
                                          bytesPerRow: bytesPerRow,
                                          space: CGColorSpaceCreateDeviceRGB(),
                                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
                print("Error: Unable to create bitmap context")
                return
            }
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: CGFloat(width), height: CGFloat(height)))
        }
        
        return pixelData
    }

    private func convertToJSON(imageData: Data, height: Int, width: Int, encoding: String, step: Int) -> String {
        let timestamp = Date().timeIntervalSince1970
        let sec = Int(timestamp)
        let nsec = Int((timestamp - Double(sec)) * 1_000_000_000)
        let imageArray = [UInt8](imageData)
        
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
                "data": imageArray
            ]
        ]

        if let jsonData = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted) {
            return String(data: jsonData, encoding: .utf8) ?? "{}"
        } else {
            return "{}"
        }
    }
}
