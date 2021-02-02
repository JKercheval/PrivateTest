//
//  CommunicationsController.swift
//  Scratch
//
//  Created by Jeremy Kercheval on 1/12/21.
//

/*
 // Bocsch Cloud Adapter.
 // Move payloads
 Messages : JSON
 Files: files :)
 
 New architecture allows high pri and low pri.
 Messages are high pri
 Files are low pri?
 
 */


import Foundation
import MQTTClient

// These ip addresses are for the MQTT instance on my computer, these will need to match the IP Address
// of the computer that is running the MQTT.
// These will change to the IP Address of the Syngenta DataBus in the near future, then maybe the IP of the
// Nevonex device.

let mqttServerAddress = "mqtt://192.168.86.55:1883"
//let mqttServerAddress = "mqtt://172.20.10.2:1883"

extension CommunicationsController: NameDescribable {}

class CommunicationsController : NSObject, CommunicationsProtocol {
    
    var connectionURL : URL? = nil
    var communcationDelegate : CommunicationsProtocolDelegate? = nil
    private var transport = MQTTCFSocketTransport()
    fileprivate var mqttSession = MQTTSession()
    let serialQueue = DispatchQueue(label: "com.queue.plottingManager.serial")
    
    override init() {
        super.init()
        MQTTLog.setLogLevel(.error)
        self.mqttSession?.delegate = self
        
    }

    func connect(connectionUrl: URL, completion: CompletionHandler?) {
        self.connectionURL = connectionUrl
        guard let port = connectionUrl.port else {
            assertionFailure("Invalid Port")
            return
        }
        
        self.transport.host = self.connectionURL?.host
        self.transport.port = UInt32(port) //1883
        self.mqttSession?.userName = "tester"
        self.mqttSession?.password = "tester"
        mqttSession?.transport = transport
        
        guard let session = mqttSession else {
            assertionFailure("Invalid mqttSession")
            return
        }
        session.connect() { error in
            guard let someError = error else {
                debugPrint("\(#function) No Error")
                if let handler = completion {
                    handler(nil)
                }
                return
            }
            debugPrint("\(#function) Error! - \(someError.localizedDescription)")
            if let handler = completion {
                handler(someError)
            }
        }

    }
    
    func disconnect() {
        guard let session = mqttSession else {
            return
        }
        session.disconnect()
    }
}

extension CommunicationsController : MQTTSessionDelegate {
    
    func connected(_ session: MQTTSession!) {
        debugPrint("\(#function) Connected")
        
        session.subscribe(toTopics: ["planter/row" : NSNumber(integerLiteral: Int(MQTTQosLevel.atMostOnce.rawValue)),
                                     "planter/status" : NSNumber(integerLiteral: Int(MQTTQosLevel.atMostOnce.rawValue)),
                                     "planter/sessionStart" : NSNumber(integerLiteral: Int(MQTTQosLevel.atMostOnce.rawValue)),
                                     "planter/sessionData" : NSNumber(integerLiteral: Int(MQTTQosLevel.atMostOnce.rawValue))]) { (error, array) in
            guard error == nil else {
                assertionFailure("Failed to subscribe")
                debugPrint("\(#function) Error! - \(error!.localizedDescription)")
                return
            }
            debugPrint("\(#function) \(array!)")
        }
    }
    
    func connectionClosed(_ session: MQTTSession!) {
        debugPrint("\(#function) Connected")
    }
    
    func connectionRefused(_ session: MQTTSession!, error: Error!) {
        debugPrint("\(#function) Refused")
    }
    
    func connectionError(_ session: MQTTSession!, error: Error!) {
        debugPrint("\(#function) Error: \(error!.localizedDescription)")
    }
    
    func newMessage(_ session: MQTTSession!, data: Data!, onTopic topic: String!, qos: MQTTQosLevel, retained: Bool, mid: UInt32) {
        guard let messageData = data, let messageTopic = topic else {
            return
        }
        switch messageTopic {
            case "planter/row":
                handlePlanterRowData(messageData: messageData)
            case "planter/status":
                let str = String(decoding: messageData, as: UTF8.self)
                debugPrint("\(#function) \(messageTopic):\(str)")
            case "planter/sessionStart":
                handleSessionStart(messageData: messageData)
//                let str = String(decoding: messageData, as: UTF8.self)
//                debugPrint("\(#function) \(messageTopic):\(str)")
            case "planter/sessionData":
                handleSessionData(messageData: messageData)
//                let str = String(decoding: messageData, as: UTF8.self)
//                debugPrint("\(#function) \(messageTopic):\(str)")
            default:
                break
        }
    }
    
    func handlePlanterRowData(messageData : Data) {
        
        serialQueue.sync {
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .didReceiveData, object: self, userInfo: [userInfoDataReceivedKey : messageData])
            }
        }
        
    }
    
    func handleSessionStart(messageData : Data) {
        
        serialQueue.sync {
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .sessionStartNotification, object: self, userInfo: [userInfoSessionStartKey : messageData])
            }
        }
        
    }
    
    func handleSessionData(messageData : Data) {
        
        serialQueue.sync {
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .sessionDataMessageNotification, object: self, userInfo: [userInfoSessionDataReceivedKey : messageData])
            }
        }
        
    }

    
}
