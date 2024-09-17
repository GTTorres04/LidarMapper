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
        let uiImage = UIImage(cgImage: cgImage)
        return uiImage.pngData()
    }
    
    private func convertToJSON(imageData: Data, height: Int, width: Int, encoding: String, step: Int) -> String {
        let timestamp = Date().timeIntervalSince1970
        let sec = Int(timestamp)
        let nsec = Int((timestamp - Double(sec)) * 1_000_000_000)
        
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
                "data": imageData.base64EncodedString()
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
        guard let cgImage = sampleBuffer.cgImage else {
            print("Error converting CMSampleBuffer to CGImage")
            return
        }
        
        // Send the image to the WebSocket
        if let imageData = cgImageToData(cgImage) {
            let width = cgImage.width
            let height = cgImage.height
            let encoding = "rgba8"
            let step = width * 4 // Assuming 4 bytes per pixel
            
            G = cgImage.colorSpace ?? CGColorSpaceCreateDeviceRGB()
            j = cgImage.bitmapInfo
            
            let json = self.convertToJSON(imageData: imageData, height: height, width: width, encoding: encoding, step: step)
            self.webSocketManager.send(message: json)
            
            if let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
                let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
                let context = CIContext()
                if let cgImage = context.createCGImage(ciImage, from: ciImage.extent) {
                    DispatchQueue.main.async {
                        self.addToPreviewStream?(cgImage)
                    }
                }
            }

        } else {
            print("Error converting CGImage to Data")
        }
        
        // Send the image to the preview stream for UI updates
        addToPreviewStream?(cgImage)
    }
}

extension CMSampleBuffer {
    var image: CGImage? {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(self) else {
            print("Error: Unable to get image buffer from sample buffer.")
            return nil
        }
        
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext(options: nil)
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            print("Error: Unable to create CGImage from CIImage.")
            return nil
        }
        
        return cgImage
    }
}

    
