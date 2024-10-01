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
        
        defer {
            free(pixelData)  // Ensure memory is freed when done
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
        
        // Draw the CGImage into the context (this renders the image into pixelData)
        context.draw(imageRef, in: CGRect(x: 0, y: 0, width: CGFloat(width), height: CGFloat(height)))
        
        // Convert the pixel data to a Data object
        let data = Data(bytes: pixelData, count: width * height * 4)
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let executionTime = endTime - startTime
        print("Execution time for cgImageToData: \(executionTime) seconds")
        
        return data
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

extension Camera: AVCaptureVideoDataOutputSampleBufferDelegate {
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Convert to CGImage in background queue to avoid blocking the main thread
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let cgImage = sampleBuffer.cgImage else {
                print("Error converting CMSampleBuffer to CGImage")
                return
            }
            
            // Dispatch the captured image to the main thread for the preview stream
            DispatchQueue.main.async {
                self?.addToPreviewStream?(cgImage)
            }
            
            // Process the image (e.g., send it over WebSocket) on a background thread
            DispatchQueue.global(qos: .background).async { [weak self] in
                guard let imageData = self?.cgImageToData(cgImage) else {
                    print("Error converting CGImage to Data")
                    return
                }
                
                let width = cgImage.width
                let height = cgImage.height
                let encoding = "rgba8"
                let step = width * 4 // Assuming 4 bytes per pixel
                
                let json = self?.convertToJSON(imageData: imageData, height: height, width: width, encoding: encoding, step: step)
                
                // Ensure the WebSocketManager send is executed on the main thread (if necessary)
                DispatchQueue.main.async {
                    if let json = json {
                        self?.webSocketManager.send(message: json)
                    } else {
                        print("Error: JSON is nil")
                    }
                }
            }
            
            let endTime = CFAbsoluteTimeGetCurrent()
            let executionTime = endTime - startTime
            print("Execution time for captureOutput: \(executionTime) seconds")
        }
    }

}



