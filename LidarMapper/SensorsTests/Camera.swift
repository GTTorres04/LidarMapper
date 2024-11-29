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
    
    @Published var pointCloudData: [(x: Float, y: Float, z: Float)] = []
    
    private var lastFrameTime: CFAbsoluteTime = 0
    private var frameInterval: CFAbsoluteTime = 1.0 / 15.0 // 15 FPS target
    
    private let ciContext = CIContext()
    
    // Camera Info Properties
        var height: Int
        var width: Int
        var distortionModel: String
        var D: [Double]
        var K: [Double]
        var R: [Double]
        var P: [Double]
        var binning_X: Int
        var binning_Y: Int
        var roi: [Double]
    
        //private var pointCloudDataHandler: PointCloudData
    
    init(webSocketManager: WebSocketManager,
            height: Int = 144,
            width: Int = 192,
            distortionModel: String = "plumb_bob",
            D: [Double] = [],
            K: [Double] = [],
            R: [Double] = [],
            P: [Double] = [],
            binning_X: Int = 1,
            binning_Y: Int = 1,
            calibrationData: AVCameraCalibrationData? = nil) {
           
           // Initialize camera info properties
           self.height = height
           self.width = width
           self.distortionModel = distortionModel
           self.binning_X = binning_X
           self.binning_Y = binning_Y
           self.roi = [0.0, 0.0, 0.0, 0.0] // Default ROI
           
               // Initialize D, K, R, P with default values provided by David Portugal
               self.D = [0.0, 0.0, 0.0, 0.0, 0.0] // Default distortion coefficients
               
               let fx = Double(width) // Approximate focal length as image width
               let fy = Double(height) // Approximate focal length as image height
               let cx = Double(width) / 2.0 // Principal point x-coordinate (image center)
               let cy = Double(height) / 2.0 // Principal point y-coordinate (image center)

               self.K = [
                       fx,  0.0, cx,
                       0.0, fy,  cy,
                       0.0, 0.0, 1.0
                   ]
               //Camera Matrix
               self.R = [ 7.1998919677734375e+02, 0.0, 3.5894522094726562e+02,
                          0.0, 7.1998919677734375e+02, 4.8530447387695312e+02,
                          0.0, 0.0, 1.0 ]
               
               //Projection Matrix:
               self.P = [ -1.19209290e-07, 0.0, 1.00000012e+00,
                           0.0, 0.0, -1.00000024e+00,
                           0.0, 0.0, 1.00000012e+00,
                           0.0, -1.19209290e-07, 0.0 ]
            // TO SEE /camera and /camera_info - Cant see /point_cloud
           //self.pointCloudDataHandler = PointCloudData()
           
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
        // camera resolution for testing
        captureSession.sessionPreset = .low
        
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
        guard !captureSession.isRunning else { return }
        
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.captureSession.startRunning()
                continuation.resume()
            }
        }
    }
    
    func stopSession() {
        if captureSession.isRunning {
            captureSession.stopRunning()
            clearMemory() // Clean up resources when stopping
        }
    }
    
    lazy var previewStream: AsyncStream<CGImage> = {
        AsyncStream { continuation in
            addToPreviewStream = { cgImage in
                continuation.yield(cgImage)
            }
        }
    }()
    
    private func cgImageFromSampleBuffer(_ sampleBuffer: CMSampleBuffer) -> CGImage? {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            print("Error: Could not get image buffer from sampleBuffer")
            return nil
        }
        
        
        
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        return ciContext.createCGImage(ciImage, from: ciImage.extent)
    }
    func clearMemory() {
        // Clear any residual data stored in image buffers (if necessary)
        self.image = nil
        // Reset last frame time if needed
        self.lastFrameTime = 0
    }
}


extension Camera: AVCaptureVideoDataOutputSampleBufferDelegate {
    
    //MARK: - Access the Camera Object, Capture Output
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        let currentTime = CFAbsoluteTimeGetCurrent()
        
        // Skip frames if they are too close in time
        guard currentTime - lastFrameTime >= frameInterval else { return }
        lastFrameTime = currentTime
        
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
        
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self = self else { return }
            
            // This method should now be faster due to the above optimizations
            self.addToPreviewStream?(cgImage)
            
            
            // Compress and send over WebSocket
            if let imageData = self.cgImageToData(cgImage) {
                let width = cgImage.width
                let height = cgImage.height
                let encoding = "rgba8"
                let step = width * 4 // Assuming 4 bytes per pixel
                
                let test = self.getCameraInfo()
                self.webSocketManager.send(message: test)
                
                let json = self.convertToJSON(imageData: imageData, height: height, width: width, encoding: encoding, step: step)
                self.webSocketManager.send(message: json) // Send this in background to avoid blocking
                
            }
            
            Task {
                if await self.memoryUsageIsHigh() {
                    self.clearMemory()
                }
            }
        }
    }
    
    // A function to check if memory usage is high
    func memoryUsageIsHigh() async -> Bool {
        // Implement logic to determine if memory usage is above a threshold
        // For example, you can use mach_task_basic_info to get current memory usage
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        if result == KERN_SUCCESS {
            let usedMemory = info.resident_size
            let threshold: UInt64 = 3 * 1024 * 1024 * 1024 // Set a threshold 3GB
            return usedMemory > threshold
        }
        
        return false
    }
    
    func cgImageToData(_ cgImage: CGImage) -> Data? {
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
    
    // Convert CGImage to JPEG to reduce memory footprint
    //Not Implemented
    private func cgImageToJPEGData(_ cgImage: CGImage) -> Data? {
        let uiImage = UIImage(cgImage: cgImage)
        return uiImage.jpegData(compressionQuality: 0.8) // Compress to reduce memory usage
    }
    
    //MARK: - Convert to Images JSON messages
    private func getCameraInfo() -> String{
        let height = self.height
        let width = self.width
        let distortionModel = "plumb_bob"
        var D :[Double] = D
        var K :[Double] = K
        var R :[Double] = R
        var P :[Double] = P
        let binning_X = 1
        let binning_Y = 1

        
        //Fill DKRP values
        
        let timestamp = Date().timeIntervalSince1970
        let sec = Int(timestamp)
        let nsec = Int((timestamp - Double(sec)) * 1_000_000_000)
        
        let json: [String: Any] = [
            "op": "publish",
            "topic": "/camera/camera_info",
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
                "distortion_model": distortionModel,
                "D": D,
                "K": K,
                "R": R,
                "P": P,
                "binning_x": binning_X,
                "binning_y": binning_Y,
                "roi": [
                    "x_offset": 0,
                    "y_offset": 0,
                    "height": height,
                    "width": width,
                    "do_rectify": false
                ]
            ]
        ]
        
        if let jsonData = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted) {
            return String(data: jsonData, encoding: .utf8) ?? "{}"
        } else {
            return "{}"
        }
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



