//
//  WebSocketTest.swift
//  LidarMapper
//
//  Created by Forestry Robotics UC on 29/07/2024.
//
import SwiftUI
import UIKit
import Foundation

class WebSocketManager: NSObject, ObservableObject, URLSessionWebSocketDelegate {
    
    @Published var receivedMessage: String = ""
    private var webSocket: URLSessionWebSocketTask?
    private var session: URLSession
    private var url: URL?
    
    override init() {
        // IP adress from the internet - chek if iPhone and Mac share the same Wi - Fi
        // and put IPv4 Adress :9090
        self.url = URL(string: "ws://10.231.216.101:9090")
        
        // Set the delegate during the URLSession initialization
        self.session = URLSession(configuration: .default, delegate: nil, delegateQueue: OperationQueue.main)
        super.init()
        
        // Assign the delegate after the super.init()
        self.session = URLSession(configuration: .default, delegate: self, delegateQueue: OperationQueue.main)
        
        // Initialize and resume the WebSocket connection
        if let url = self.url {
            self.webSocket = session.webSocketTask(with: url)
            self.webSocket?.resume()
        }
    }
    
    func ping() {
        webSocket?.sendPing { error in
            if let error = error {
                print("Ping error: \(error)")
            }
        }
    }
    
    func close() {
        webSocket?.cancel(with: .goingAway, reason: "Demo ended".data(using: .utf8))
    }
    
    func send(message: String) {
        webSocket?.send(.string(message), completionHandler: { error in
            if let error = error {
                print("Send error: \(error)")
            }
        })
    }
    
    func receive() {
        webSocket?.receive { result in
            switch result {
            case .success(let message):
                switch message {
                case .data(let data):
                    print("Got Data: \(data)")
                case .string(let message):
                    print("Got String: \(message)")
                    DispatchQueue.main.async {
                        self.receivedMessage = message
                    }
                @unknown default:
                    break
                }
            case .failure(let error):
                print("Receive error: \(error)")
            }
            
            // Call receive again to keep listening for new messages
            self.receive()
        }
    }
    
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        print("Did Connect to Socket")
        ping()
        receive()
        send(message:
            """
            { "op": "advertise",
                "topic": "/imu/accel",
                "type": "sensor_msgs/Imu"
            }
            """
        )
    }
    
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        print("Did close connection with Socket")
    }
}

