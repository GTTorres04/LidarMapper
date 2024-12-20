//
//  PointCloudData.swift
//  LidarMapper
//
//  Created by Forestry Robotics UC on 15/11/2024.
//

import ARKit
import SceneKit
import Foundation
import Combine
import simd
import AVFoundation


class PointCloudData: NSObject, ARSessionDelegate, ObservableObject, AVCaptureDepthDataOutputDelegate {
    private var session: ARSession
    @Published var webSocketManager: WebSocketManager
    
    @Published var pointCloud: [(x: Float, y: Float, z: Float)] = []
    
    
    
    override init() {
        webSocketManager = WebSocketManager()
        session = ARSession()
        super.init()
        //CameraManager.shared.addDepthDelegate(self)
        setupARSession()
        session.delegate = self
    }
    
    // Initialize iPhone LiDAR Data Capture
    private func setupARSession() {
        let config = ARWorldTrackingConfiguration()
        config.sceneReconstruction = .mesh
        config.frameSemantics = .sceneDepth
        session.delegate = self
        session.run(config)
    }
    
    
    
    //Extract Point Cloud Data from Depth Map
    private func extractPointCloudFromDepth(frame: ARFrame, depthData: ARDepthData) -> [(x: Float, y: Float, z: Float)]? {
        
        resetPointCloud()
        pointCloud = []
        
        
        // Use rawFeaturePoints if available, or default to an empty array
        guard let featurePoints = frame.rawFeaturePoints?.points
        else {
            return pointCloud
        }
        
        // Convert the array of SIMD3<Float> to a tuple array [(x: Float, y: Float, z: Float)]
        pointCloud = featurePoints.map { (x: $0.x, y: $0.y, z: $0.z) }
        
        /*guard let intrinsics = getCameraIntrinsics(from: frame) else { return [] }
         
         let (fx, fy, cx, cy) = (intrinsics.fx, intrinsics.fy, intrinsics.cx, intrinsics.cy)
         let depthMap = depthData.depthMap
         let width = CVPixelBufferGetWidth(depthMap)
         let height = CVPixelBufferGetHeight(depthMap)
         
         CVPixelBufferLockBaseAddress(depthMap, .readOnly)
         defer { CVPixelBufferUnlockBaseAddress(depthMap, .readOnly) }
         frame.rawFeaturePoints?.points
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
         }
         }
         return pointCloud*/
        pointCloud = []
        return pointCloud
    }
    
    //Convert Mesh to Point Cloud Data
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
    
    private func getCameraIntrinsics(from frame: ARFrame) -> (fx: Float, fy: Float, cx: Float, cy: Float)? {
        let intrinsics = frame.camera.intrinsics
        let fx = intrinsics[0, 0]
        let fy = intrinsics[1, 1]
        let cx = intrinsics[0, 2]
        let cy = intrinsics[1, 2]
        return (fx, fy, cx, cy)
    }
    
    private var lastSendTime: TimeInterval = 0
    private let minInterval: TimeInterval = 1.0 / 15.0 // 15 Hz
    
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        // Only proceed if enough time has passed to send data
        let currentTime = Date().timeIntervalSince1970
        guard currentTime - lastSendTime >= minInterval else { return }
        lastSendTime = currentTime
        
        // Reset the point cloud and prepare to combine
        var combinedPointCloud: [(x: Float, y: Float, z: Float)] = []
        
        // Extract point cloud from depth data if available
        if let sceneDepth = frame.sceneDepth, let depthPointCloud = extractPointCloudFromDepth(frame: frame, depthData: sceneDepth) {
            combinedPointCloud.append(contentsOf: depthPointCloud)
        }
        
        // Convert mesh data to point cloud and combine
        let meshPointCloud = convertMeshToPointCloud(anchors: frame.anchors)
        combinedPointCloud.append(contentsOf: meshPointCloud)
        
        // If the combined point cloud is not empty, send to ROS
        if !combinedPointCloud.isEmpty {
            DispatchQueue.global(qos: .background).async {
                self.sendPointCloudToROS(pointCloud: combinedPointCloud)
            }
        }
        
        // Process the camera image in parallel with point cloud transmission
        /*DispatchQueue.global(qos: .background).async { [weak self] in
            self?.processCapturedImage(cameraImage)
        }*/
    }
    
    //let camera = Camera(webSocketManager: WebSocketManager())
    
    
    
    
    // Function to reset the point cloud buffer
    func resetPointCloud() {
        pointCloud.removeAll(keepingCapacity: false)
    }
    
    
    // Format Data for ROS
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
                    "frame_id": "lidar_frame",
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
    
    // Helper function to encode point cloud data into a byte array
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
}
