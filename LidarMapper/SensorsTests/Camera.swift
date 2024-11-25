//
//  Camera.swift
//  LidarMapper
//
//  Created by Forestry Robotics UC on 05/09/2024.
//
import Foundation
import AVFoundation
import UIKit
import ARKit
import Combine
import simd

class Camera: NSObject, ObservableObject, ARSessionDelegate {
    
    let captureSession = AVCaptureSession()
    private var deviceInput: AVCaptureDeviceInput?
    private var videoOutput: AVCaptureVideoDataOutput?
    private let systemPreferredCamera = AVCaptureDevice.default(for: .video)
    private let sessionQueue = DispatchQueue(label: "video.preview.session")
    
    private let session = ARSession()
    
    
    @Published var image: CGImage?
    var addToPreviewStream: ((CGImage) -> Void)?
    @Published var webSocketManager = WebSocketManager()
    
    @Published var pointCloudData: [(x: Float, y: Float, z: Float)] = []
    
        private var lastFrameTime: CFAbsoluteTime = 0
        private var frameInterval: CFAbsoluteTime = 1.0 / 15.0 // 15 FPS target
        private var lastSendTime: TimeInterval = 0
        private let minInterval: TimeInterval = 1.0 / 15.0 // 15 Hz for point cloud data
    
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
           
                    
           
           if let calibrationData = calibrationData {
               // Lens Distortion
               self.D = calibrationData.lensDistortionLookupTable?.map(Double.init) ?? []
               
               // Validate D
               assert(!D.isEmpty, "Distortion coefficients D must not be empty")
               
               // Intrinsic Matrix (3x3)
               let intrinsicMatrix = calibrationData.intrinsicMatrix
               self.K = [
                   Double(intrinsicMatrix[0][0]), Double(intrinsicMatrix[0][1]), Double(intrinsicMatrix[0][2]),
                   Double(intrinsicMatrix[1][0]), Double(intrinsicMatrix[1][1]), Double(intrinsicMatrix[1][2]),
                   Double(intrinsicMatrix[2][0]), Double(intrinsicMatrix[2][1]), Double(intrinsicMatrix[2][2])
               ]

               // Ensure K contains 9 elements:
               assert(self.K.count == 9, "Intrinsic matrix K must have exactly 9 elements")

               
               // Extrinsic Matrix (3x3)
               let extrinsicMatrix = calibrationData.extrinsicMatrix
                   self.R = (0..<3).flatMap { row in
                       (0..<3).map { col in Double(extrinsicMatrix[row][col]) }
                   }
               
               assert(R.count == 9, "Rotation matrix R must have exactly 9 elements")
               
               
               // Projection Matrix (4x4)
               self.P = [
                       Double(intrinsicMatrix[0][0]), Double(intrinsicMatrix[0][1]), Double(intrinsicMatrix[0][2]), 0.0,
                       Double(intrinsicMatrix[1][0]), Double(intrinsicMatrix[1][1]), Double(intrinsicMatrix[1][2]), 0.0,
                       Double(intrinsicMatrix[2][0]), Double(intrinsicMatrix[2][1]), Double(intrinsicMatrix[2][2]), 0.0
                   ]
               
               // Validate P
               assert(P.count == 12, "Projection matrix P must have exactly 12 elements")
               
               if distortionModel == "plumb_bob" {
                   assert(D.count == 5, "Distortion model 'plumb_bob' requires exactly 5 coefficients")
               }
               
               
           } else {
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
           }
            // TO SEE /camera and /camera_info - Cant see /point_cloud
           //self.pointCloudDataHandler = PointCloudData()
           
           super.init()
           setupARSession()
           self.webSocketManager = webSocketManager
           
           Task {
               await configureSession()
               await startSession()
           }
        
        //CameraManager.shared.addVideoDelegate(self)
       }
    
    func check() {
        if captureSession.isRunning {
            captureSession.stopRunning()
        }
    }
    
    

    let config = ARWorldTrackingConfiguration()
    
    // MARK: - ARKit Setup
        func setupARSession() {
            check()
            config.sceneReconstruction = .mesh
            config.frameSemantics = .sceneDepth
            config.planeDetection = .horizontal
            session.delegate = self
            session.pause()
            session.run(config, options: [.resetTracking, .removeExistingAnchors])
        }
    
    
    
    
    private func configureSession() async {
            check()
            captureSession.stopRunning()
            guard let systemPreferredCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
                  let deviceInput = try? AVCaptureDeviceInput(device: systemPreferredCamera) else {
                print("Error: Unable to access the camera.")
                return
            }
        
        

            do {
                try systemPreferredCamera.lockForConfiguration()
                
                // Select the default or ARKit-compatible format
                if let compatibleFormat = systemPreferredCamera.formats.first(where: { format in
                    format.isVideoBinned == false && format.videoSupportedFrameRateRanges.contains { $0.maxFrameRate >= 30 }
                }) {
                    systemPreferredCamera.activeFormat = compatibleFormat
                } else {
                    print("Warning: No compatible format found, using the current active format.")
                }
                
                systemPreferredCamera.unlockForConfiguration()
                
                let config = ARWorldTrackingConfiguration()
                
                // MARK: - ARKit Setup
                    func setupARSession() {
                        config.sceneReconstruction = .mesh
                        config.frameSemantics = .sceneDepth
                        session.delegate = self
                        session.pause()
                        session.run(config, options: [.resetTracking, .removeExistingAnchors])
                    }
            } catch {
                print("Error configuring camera: \(error.localizedDescription)")
                return
            }

            captureSession.beginConfiguration()
            defer {
                captureSession.commitConfiguration()
            }

            // Set the session preset for testing (e.g., low resolution)
            captureSession.sessionPreset = .low

            let videoOutput = AVCaptureVideoDataOutput()
            videoOutput.setSampleBufferDelegate(self, queue: sessionQueue)

            // Add inputs and outputs to the session
            if captureSession.canAddInput(deviceInput) && captureSession.canAddOutput(videoOutput) {
                captureSession.addInput(deviceInput)
                captureSession.addOutput(videoOutput)
            } else {
                print("Error: Unable to add input/output to capture session.")
            }
        }

    
    func startSession() async {
        check()
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
    
    // MARK: - ARSession Delegate Method for Point Cloud
    func session(_ session: ARSession, didUpdate frame: ARFrame, didFailWithError error: Error) {
        let currentTime = Date().timeIntervalSince1970
        guard currentTime - lastSendTime >= minInterval else { return }
        lastSendTime = currentTime

        var combinedPointCloud: [(x: Float, y: Float, z: Float)] = []

        // Extract point cloud from the depth data
        if let sceneDepth = frame.sceneDepth {
            if let depthPointCloud = extractPointCloudFromDepth(frame: frame, depthData: sceneDepth) {
                combinedPointCloud += depthPointCloud
            }
            
            // Present an error message to the user
            print("ARSession failed with error: \(error.localizedDescription)")

                if let arError = error as? ARError {
                    switch arError.errorCode {
                    case 102:
                        config.worldAlignment = .gravity
                        restartSessionWithoutDelete()
                    default:
                        restartSessionWithoutDelete()
                    }
                }
        }

        // Add points from the mesh anchors
        combinedPointCloud += convertMeshToPointCloud(anchors: frame.anchors)

        // Send point cloud to ROS
        if !combinedPointCloud.isEmpty {
            sendPointCloudToROS(pointCloud: combinedPointCloud)
        }
    }
    
    @objc func restartSessionWithoutDelete() {
        // Restart session with a different worldAlignment - prevents bug from crashing app
        self.session.pause()
        self.session.run(config, options: [
            .resetTracking,
            .removeExistingAnchors])
    }

    
    func sendPointCloudToROS(pointCloud: [(x: Float, y: Float, z: Float)]) {
        guard !pointCloud.isEmpty else { return }
        
        // Get the current timestamp
        let timestamp = Date().timeIntervalSince1970
        let sec = Int(timestamp)
        let nsec = Int((timestamp - Double(sec)) * 1_000_000_000)
        
        // Create the ROS message
        let json: [String: Any] = [
            "op": "publish",
            "topic": "/point_cloud",
            "msg": [
                "header": [
                    "frame_id": "camara",
                    "stamp": [
                        "sec": sec,
                        "nsec": nsec
                    ]
                ],
                "height": 1, // Unstructured point cloud
                "width": pointCloud.count,
                "fields": [
                    ["name": "x", "offset": 0, "datatype": 7, "count": 1], // datatype 7 = FLOAT32
                    ["name": "y", "offset": 4, "datatype": 7, "count": 1],
                    ["name": "z", "offset": 8, "datatype": 7, "count": 1]
                ],
                "is_bigendian": false,
                "point_step": 12, // 4 bytes each for x, y, z
                "row_step": 12 * pointCloud.count,
                "data": encodePointCloudData(pointCloud),
                "is_dense": true
            ]
        ]
        
        // Convert the JSON to a string
        if let jsonData = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted) {
            let jsonString = String(data: jsonData, encoding: .utf8) ?? "{}"
            webSocketManager.send(message: jsonString)
        }
    }
    
    private func encodePointCloudData(_ pointCloud: [(x: Float, y: Float, z: Float)]) -> [UInt8] {
        var data = [UInt8]()
        for point in pointCloud {
            var x = point.x
            var y = point.y
            var z = point.z
            withUnsafeBytes(of: &x) { data.append(contentsOf: $0) }
            withUnsafeBytes(of: &y) { data.append(contentsOf: $0) }
            withUnsafeBytes(of: &z) { data.append(contentsOf: $0) }
        }
        return data
    }
    
    //MARK: - Extract Point Cloud Data from Depth Map
    private func extractPointCloudFromDepth(frame: ARFrame, depthData: ARDepthData) -> [(x: Float, y: Float, z: Float)]? {
        guard let intrinsics = getCameraIntrinsics(from: frame) else { return [] }
        
        let (fx, fy, cx, cy) = (intrinsics.fx, intrinsics.fy, intrinsics.cx, intrinsics.cy)
        let depthMap = depthData.depthMap
        let width = CVPixelBufferGetWidth(depthMap)
        let height = CVPixelBufferGetHeight(depthMap)
        
        CVPixelBufferLockBaseAddress(depthMap, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(depthMap, .readOnly) }
        
        guard let baseAddress = CVPixelBufferGetBaseAddress(depthMap) else { return [] }
        let rowBytes = CVPixelBufferGetBytesPerRow(depthMap)
        
        var pointCloud: [(x: Float, y: Float, z: Float)] = []
        
        for y in stride(from: 0, to: height, by: 2) { // Process every 2nd row for speed
            for x in stride(from: 0, to: width, by: 2) { // Process every 2nd column
                let depth = baseAddress
                    .advanced(by: y * rowBytes + x * MemoryLayout<Float>.size)
                    .assumingMemoryBound(to: Float.self)
                    .pointee
                if depth > 0 {
                    let xWorld = (Float(x) - cx) * depth / fx
                    let yWorld = (Float(y) - cy) * depth / fy
                    let zWorld = depth
                    pointCloud.append((x: xWorld, y: yWorld, z: zWorld))
                }
                // Skip invalid depth values
                if depth == 0 {
                    continue
                }
                
            }
        }
        
        // Unlock the base address after reading the pixel data
        CVPixelBufferUnlockBaseAddress(depthMap, .readOnly)
        
        return pointCloud
    }
    
    // MARK: - Retrieve Camera Intrinsics
    private func getCameraIntrinsics(from frame: ARFrame) -> (fx: Float, fy: Float, cx: Float, cy: Float)? {
        // Camera intrinsics are stored in the ARFrame's camera properties
        let intrinsics = frame.camera.intrinsics
        
        let fx = intrinsics[0, 0]
        let fy = intrinsics[1, 1]
        let cx = intrinsics[0, 2]
        let cy = intrinsics[1, 2]
        
        return (fx, fy, cx, cy)
    }
    
    //MARK: - Convert Mesh to Point Cloud Data
    private func convertMeshToPointCloud(anchors: [ARAnchor]) -> [(x: Float, y: Float, z: Float)] {
        var pointCloud: [(x: Float, y: Float, z: Float)] = []
        
        for anchor in anchors {
            guard let meshAnchor = anchor as? ARMeshAnchor else { continue }
            let geometry = meshAnchor.geometry
            
            let vertexBuffer = geometry.vertices
            let vertexData = vertexBuffer.buffer.contents() // Get the raw buffer pointer
            
            // Iterate over the vertices
            for i in 0..<vertexBuffer.count {
                let vertexPointer = vertexData.advanced(by: i * vertexBuffer.stride)
                let vertex = vertexPointer.assumingMemoryBound(to: simd_float3.self).pointee
                
                // Transform vertex into world space using the anchor's transform
                let worldVertex = simd_make_float4(vertex, 1.0)
                let transformedVertex = meshAnchor.transform * worldVertex
                
                pointCloud.append((x: transformedVertex.x, y: transformedVertex.y, z: transformedVertex.z))
            }
        }
        
        return pointCloud
    }
    
    
    
}



