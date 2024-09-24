//
//  CMSampleBuffer+Extention.swift
//  LidarMapper
//
//  Created by Forestry Robotics UC on 05/09/2024.
//
import AVFoundation
import CoreImage

extension CMSampleBuffer {
    var cgImage: CGImage? {
            guard let pixelBuffer = CMSampleBufferGetImageBuffer(self) else {
                print("Error: No pixel buffer found")
                return nil
            }
            
            // Convert to CIImage
            let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
            
            // Convert CIImage to CGImage using a context
            let context = CIContext()
            guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
                print("Error: Unable to create CGImage from CIImage")
                return nil
            }
            
            return cgImage
        }
}
