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


class PointCloudData: NSObject, ARSessionDelegate, ObservableObject {
    private var session: ARSession
    @Published var webSocketManager: WebSocketManager
    
    
    override init() {
        webSocketManager = WebSocketManager()
        session = ARSession()
        super.init()
        setupARSession()
        //setupROSWebSocket()
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
        guard let intrinsics = getCameraIntrinsics(from: frame) else { return nil }
        
        let fx = intrinsics.fx
        let fy = intrinsics.fy
        let cx = intrinsics.cx
        let cy = intrinsics.cy
        
        let depthMap = depthData.depthMap
        let width = CVPixelBufferGetWidth(depthMap)
        let height = CVPixelBufferGetHeight(depthMap)
        
        CVPixelBufferLockBaseAddress(depthMap, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(depthMap, .readOnly) }
        
        let baseAddress = CVPixelBufferGetBaseAddress(depthMap)
        var pointCloud: [(x: Float, y: Float, z: Float)] = []
        
        for y in 0..<height {
            for x in 0..<width {
                let depth = baseAddress?.advanced(by: y * CVPixelBufferGetBytesPerRow(depthMap) + x * MemoryLayout<Float>.size).assumingMemoryBound(to: Float.self).pointee ?? 0
                if depth > 0 {
                    let xWorld = (Float(x) - cx) * depth / fx
                    let yWorld = (Float(y) - cy) * depth / fy
                    let zWorld = depth
                    pointCloud.append((x: xWorld, y: yWorld, z: zWorld))
                }
            }
        }
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
    
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        if let sceneDepth = frame.sceneDepth {
            if let depthPointCloud = extractPointCloudFromDepth(frame: frame, depthData: sceneDepth) {
                sendPointCloudToROS(pointCloud: depthPointCloud)
            }
        }

        let meshPointCloud = convertMeshToPointCloud(anchors: frame.anchors)
        if !meshPointCloud.isEmpty {
            sendPointCloudToROS(pointCloud: meshPointCloud)
        }
    }
    
    
    // Format Data for ROS
    func sendPointCloudToROS(pointCloud: [(x: Float, y: Float, z: Float)]) {
        guard !pointCloud.isEmpty else { return }
        
        for point in pointCloud {
                print("Point: (\(point.x), \(point.y), \(point.z))")
        }


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
