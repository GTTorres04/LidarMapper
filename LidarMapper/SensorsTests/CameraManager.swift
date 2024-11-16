//
//  CameraManager.swift
//  LidarMapper
//
//  Created by Forestry Robotics UC on 16/11/2024.
//

import AVFoundation

class CameraManager: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureDepthDataOutputDelegate {
    static let shared = CameraManager()

    private let captureSession = AVCaptureSession()
    private var videoOutput: AVCaptureVideoDataOutput?
    private var depthOutput: AVCaptureDepthDataOutput?

    private override init() {
        super.init()
        configureCaptureSession()
    }

    private func configureCaptureSession() {
        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            print("No camera available.")
            return
        }

        do {
            let videoInput = try AVCaptureDeviceInput(device: videoDevice)
            if captureSession.canAddInput(videoInput) {
                captureSession.addInput(videoInput)
            }

            let videoOutput = AVCaptureVideoDataOutput()
            videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "VideoQueue"))
            if captureSession.canAddOutput(videoOutput) {
                captureSession.addOutput(videoOutput)
            }
            self.videoOutput = videoOutput

            let depthOutput = AVCaptureDepthDataOutput()
            depthOutput.setDelegate(self, callbackQueue: DispatchQueue(label: "DepthQueue"))
            if captureSession.canAddOutput(depthOutput) {
                captureSession.addOutput(depthOutput)
            }
            self.depthOutput = depthOutput

        } catch {
            print("Error configuring capture session: \(error)")
        }

        captureSession.startRunning()
    }

    func addVideoDelegate(_ delegate: AVCaptureVideoDataOutputSampleBufferDelegate) {
        videoOutput?.setSampleBufferDelegate(delegate, queue: DispatchQueue(label: "VideoQueue"))
    }

    func addDepthDelegate(_ delegate: AVCaptureDepthDataOutputDelegate) {
        depthOutput?.setDelegate(delegate, callbackQueue: DispatchQueue(label: "DepthQueue"))
    }
}
