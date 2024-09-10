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
    var G: CGColorSpace
    var j: CGBitmapInfo
    @Published var webSocketManager: WebSocketManager
    @Published var image: CGImage?
    
    init(webSocketManager: WebSocketManager) {
        self.webSocketManager = webSocketManager
        self.image = nil // Initialize image (or any other uninitialized properties)
        super.init(cgColorSpace: CGColorSpace)
        
        // Ensure all properties are initialized before capturing `self` in the Task closure
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
    
    // Converts CGImage to Data and prepares JSON message
    //private func publishImageToROS(_ cgImage: CGImage) {
        //guard cgImageToData(cgImage) != nil else { return }
    //}
    
    private var addToPreviewStream: ((CGImage) -> Void)?
        
        lazy var previewStream: AsyncStream<CGImage> = {
            AsyncStream { continuation in
                addToPreviewStream = { cgImage in
                    continuation.yield(cgImage)
                }
            }
        }()
    
    
    
    // Convert CGImage to PNG Data
    func cgImageToData(_ cgImage: CGImage) -> Data? {
        let uiImage = UIImage(cgImage: cgImage)

        return uiImage.pngData()
    }
    

    
    
    private func convertToJSON(imageData: Data, height: Int, width: Int, encoding: String, step: Int) -> String {
        let timestamp = Date().timeIntervalSince1970
        let sec = Int(timestamp)
        let nsec = Int((timestamp - Double(sec)) * 1_000_000_000)
        
        //let array = [UInt8](cgImageToData(CGImage.self as! CGImage)!)
        
        
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
                        "encoding": encoding,  // "rgb8"
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
    
    func printState() {
        print(G)
        print(j)
    }
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        if let cgImage = sampleBuffer.cgImage {
            if let imageData = cgImageToData(cgImage) {
                let width = cgImage.width
                let height = cgImage.height
                let encoding = "rgba8"  // Assuming the image is RGB
                let step = width * 3    // 3 bytes per pixel for RGB
                G = cgImage.colorSpace ?? 0 as! CGColorSpace
                j = cgImage.bitmapInfo
                

                let json = self.convertToJSON(imageData: imageData, height: height, width: width, encoding: encoding, step: step)
                self.webSocketManager.send(message: json)
            } else {
                print("Error converting CGImage to Data")
            }
        } else {
            print("Error converting CMSampleBuffer to CGImage")
        }
    }
}

    
