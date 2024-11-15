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


class PointCloudData: NSObject, ARSessionDelegate {
    private var session: ARSession
    private var rosWebSocket: URLSessionWebSocketTask?

    override init() {
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
}
