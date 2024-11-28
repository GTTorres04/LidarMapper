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

class PointCloudData: NSObject, ARSessionDelegate, ObservableObject, AVCaptureDepthDataOutputDelegate {
    private var session: ARSession
    @Published var webSocketManager: WebSocketManager

    @Published var pointCloud: [(x: Float, y: Float, z: Float, r: Float, g: Float, b: Float)] = []

    override init() {
        webSocketManager = WebSocketManager()
        session = ARSession()
        super.init()
        setupARSession()
        session.delegate = self
    }

    private func setupARSession() {
        let config = ARWorldTrackingConfiguration()
        config.sceneReconstruction = .mesh
        config.frameSemantics = .sceneDepth
        session.delegate = self
        session.run(config)
    }

    private func extractPointCloudFromDepth(frame: ARFrame, depthData: ARDepthData) -> [(x: Float, y: Float, z: Float, r: Float, g: Float, b: Float)]? {
        var pointCloud: [(x: Float, y: Float, z: Float, r: Float, g: Float, b: Float)] = []
        guard let intrinsics = getCameraIntrinsics(from: frame) else { return [] }

        let (fx, fy, cx, cy) = (intrinsics.fx, intrinsics.fy, intrinsics.cx, intrinsics.cy)
        let depthMap = depthData.depthMap
        let width = CVPixelBufferGetWidth(depthMap)
        let height = CVPixelBufferGetHeight(depthMap)

        let colorPixelBuffer = frame.capturedImage
        CVPixelBufferLockBaseAddress(colorPixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(colorPixelBuffer, .readOnly) }

        let colorBaseAddress = CVPixelBufferGetBaseAddress(colorPixelBuffer)!
        let colorBytesPerRow = CVPixelBufferGetBytesPerRow(colorPixelBuffer)

        guard let baseAddress = CVPixelBufferGetBaseAddress(depthMap) else { return [] }
        let rowBytes = CVPixelBufferGetBytesPerRow(depthMap)

        // Transformation matrix from LiDAR to camera
        let lidarToCameraTransform = frame.camera.transform

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

                    // Apply the transformation from LiDAR to camera
                    let lidarPoint = simd_float4(xWorld, yWorld, zWorld, 1.0)
                    let cameraPoint = lidarToCameraTransform * lidarPoint

                    // Extract RGB values from the color buffer
                    let pixelOffset = y * colorBytesPerRow + x * 4 // Assuming RGBA format
                    let r = Float(colorBaseAddress.load(fromByteOffset: pixelOffset, as: UInt8.self)) / 255.0
                    let g = Float(colorBaseAddress.load(fromByteOffset: pixelOffset + 1, as: UInt8.self)) / 255.0
                    let b = Float(colorBaseAddress.load(fromByteOffset: pixelOffset + 2, as: UInt8.self)) / 255.0

                    pointCloud.append((x: cameraPoint.x, y: cameraPoint.y, z: cameraPoint.z, r: r, g: g, b: b))
                }
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

    func sendPointCloudToROS(pointCloud: [(x: Float, y: Float, z: Float, r: Float, g: Float, b: Float)]) {
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
                    "frame_id": "camera",
                    "stamp": [
                        "sec": sec,
                        "nsec": nsec
                    ]
                ],
                "height": 1, // Unstructured point cloud
                "width": pointCloud.count,
                "fields": [
                    ["name": "x", "offset": 0, "datatype": 7, "count": 1],
                    ["name": "y", "offset": 4, "datatype": 7, "count": 1],
                    ["name": "z", "offset": 8, "datatype": 7, "count": 1],
                    ["name": "r", "offset": 12, "datatype": 7, "count": 1],
                    ["name": "g", "offset": 16, "datatype": 7, "count": 1],
                    ["name": "b", "offset": 20, "datatype": 7, "count": 1]
                ],
                "is_bigendian": false,
                "point_step": 24, // 4 bytes each for x, y, z, r, g, b
                "row_step": 24 * pointCloud.count,
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

    private func encodePointCloudData(_ pointCloud: [(x: Float, y: Float, z: Float, r: Float, g: Float, b: Float)]) -> [UInt8] {
        var data = [UInt8]()
        for point in pointCloud {
            var x = point.x
            var y = point.y
            var z = point.z
            var r = point.r
            var g = point.g
            var b = point.b
            withUnsafeBytes(of: &x) { data.append(contentsOf: $0) }
            withUnsafeBytes(of: &y) { data.append(contentsOf: $0) }
            withUnsafeBytes(of: &z) { data.append(contentsOf: $0) }
            withUnsafeBytes(of: &r) { data.append(contentsOf: $0) }
            withUnsafeBytes(of: &g) { data.append(contentsOf: $0) }
            withUnsafeBytes(of: &b) { data.append(contentsOf: $0) }
        }
        return data
    }
}
