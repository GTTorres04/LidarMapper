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
    private let sessionQueue = DispatchQueue(label: "video.preview.session")
    
    @Published var image: CGImage?
    var addToPreviewStream: ((CGImage) -> Void)?
    @Published var webSocketManager = WebSocketManager()
    
    private var lastFrameTime: CFAbsoluteTime = 0
    private var frameInterval: CFAbsoluteTime = 1.0 / 30.0 // 30 FPS target
    
    private let frameProcessingQueue = DispatchQueue(label: "frame.processing.queue", qos: .userInitiated)
    private let ciContext = CIContext()
    
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
        // Try lowering the camera resolution for testing
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
}


extension Camera: AVCaptureVideoDataOutputSampleBufferDelegate {
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        let currentTime = CFAbsoluteTimeGetCurrent()
        
        // Skip frames if they are too close in time
        guard currentTime - lastFrameTime >= frameInterval else { return }
        lastFrameTime = currentTime
        
        frameProcessingQueue.async { [weak self] in
            guard let self = self else { return }

            guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
                print("Error: Could not get image buffer from sampleBuffer")
                return
            }
            
            CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
            
            let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
            guard let cgImage = self.ciContext.createCGImage(ciImage, from: ciImage.extent) else {
                print("Error creating CGImage")
                CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly)
                return
            }
            
            CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly)
            
            // Send to preview stream
            self.addToPreviewStream?(cgImage)
            
            // Compress and send over WebSocket in the background
            if let imageData = self.cgImageToData(cgImage) {
                self.frameProcessingQueue.async {
                    let width = cgImage.width
                    let height = cgImage.height
                    let encoding = "rgba8"
                    let step = width * 4
                    
                    let json = self.convertToJSON(imageData: imageData, height: height, width: width, encoding: encoding, step: step)
                    self.webSocketManager.send(message: json)
                }
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


