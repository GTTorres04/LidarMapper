//
//  CameraInfo.swift
//  LidarMapper
//
//  Created by Forestry Robotics UC on 31/10/2024.
//

import Foundation
import AVFoundation
import Combine

class CameraInfo: ObservableObject {
    
    @Published var webSocketManager = WebSocketManager()
    @Published var camera: Camera
    
    var height: Int
    var width: Int
    var distortionModel: String
    var D: [Double]
    var K: [Double]
    var R: [Double]
    var P: [Double]
    var binning_X: Int
    var binning_Y: Int
    var Roi: [Double]
    
    init(height: Int = 144,
         width: Int = 192,
         distortionModel: String = "plumb_bob",
         D: [Double] = [],
         K: [Double] = [],
         R: [Double] = [],
         P: [Double] = [],
         binning_X: Int = 1,
         binning_Y: Int = 1,
         calibrationData: AVCameraCalibrationData? = nil) {
        
        self.camera = Camera(webSocketManager: WebSocketManager())
        self.height = height
        self.width = width
        self.distortionModel = distortionModel
        self.binning_X = binning_X
        self.binning_Y = binning_Y
        self.Roi = [0.0, 0.0, 0.0, 0.0] // Default ROI
        
        if let calibrationData = calibrationData {
            // Lens Distortion
            self.D = calibrationData.lensDistortionLookupTable?.map(Double.init) ?? []
            
            // Intrinsic Matrix (3x3)
            let intrinsicMatrix = calibrationData.intrinsicMatrix
            self.K = [
                Double(intrinsicMatrix[0][0]), Double(intrinsicMatrix[0][1]), Double(intrinsicMatrix[0][2]),
                Double(intrinsicMatrix[1][0]), Double(intrinsicMatrix[1][1]), Double(intrinsicMatrix[1][2]),
                Double(intrinsicMatrix[2][0]), Double(intrinsicMatrix[2][1]), Double(intrinsicMatrix[2][2])
            ]
            
            // Extrinsic Matrix (4x4)
            let extrinsicMatrix = calibrationData.extrinsicMatrix
            self.R = (0..<4).flatMap { row in
                (0..<4).map { col in Double(extrinsicMatrix[row][col]) }
            }
            
            // Projection Matrix (4x4)
            self.P = [
                Double(intrinsicMatrix[0][0]), Double(intrinsicMatrix[0][1]), Double(intrinsicMatrix[0][2]), 0.0,
                Double(intrinsicMatrix[1][0]), Double(intrinsicMatrix[1][1]), Double(intrinsicMatrix[1][2]), 0.0,
                Double(intrinsicMatrix[2][0]), Double(intrinsicMatrix[2][1]), Double(intrinsicMatrix[2][2]), 0.0,
                0.0, 0.0, 0.0, 1.0 // Homogeneous coordinates for projection
            ]
        } else {
            // Initialize D, K, R, P with default values if no calibration data is provided
            self.D = D
            self.K = K
            self.R = R
            self.P = P
        }
    }
    
    
    private func convertToJSON(imageData: Data, height: Int, width: Int, encoding: String, step: Int) -> String {
        let timestamp = Date().timeIntervalSince1970
        let sec = Int(timestamp)
        let nsec = Int((timestamp - Double(sec)) * 1_000_000_000)
        let imageArray = [UInt8](imageData)
        
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
            "Roi": [0.0, 0.0, 0.0, 0.0]
          ]
     ]
        
        if let jsonData = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted) {
            return String(data: jsonData, encoding: .utf8) ?? "{}"
        } else {
            return "{}"
        }
    }
}
