//
//  WebSocketTest.swift
//  LidarMapper
//
//  Created by Forestry Robotics UC on 29/07/2024.
//
import SwiftUI
import Combine
import Foundation

class WebSocketManager: NSObject, ObservableObject, URLSessionWebSocketDelegate {
    
    @Published var receivedMessage: String = ""
    private var webSocket: URLSessionWebSocketTask?
    private var session: URLSession
    private var url: URL?
    
    override init() {
        self.url = URL(string: "ws://10.231.216.101:9090")
        self.session = URLSession(configuration: .default, delegate: nil, delegateQueue: OperationQueue.main)
        super.init()
        
        self.session = URLSession(configuration: .default, delegate: self, delegateQueue: OperationQueue.main)
        
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
                "topic": "/imu/accgyro",
                "type": "sensor_msgs/Imu"
            }
            """
        )

        send(message:
            """
            { "op": "advertise",
                "topic": "/imu/mag",
                "type": "sensor_msgs/MagneticField"
            }
            """
        )
    }
    
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        print("Did close connection with Socket")
    }
}


