//
//  CommunicationsController.swift
//  Scratch
//
//  Created by Jeremy Kercheval on 1/12/21.
//

import Foundation
import MQTTClient
let mqttServerAddress = "mqtt://192.168.86.29:1883"

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
            return
        }
        
        self.transport.host = self.connectionURL?.host
        self.transport.port = UInt32(port) //1883
        self.mqttSession?.userName = "tester"
        self.mqttSession?.password = "tester"
        mqttSession?.transport = transport
        
        guard let session = mqttSession else {
            return
        }
        session.connect() { error in
            guard let someError = error else {
                debugPrint("\(#function) No Error")
                if let handler = completion {
                    handler(true)
                }
                return
            }
            debugPrint("\(#function) Error! - \(someError.localizedDescription)")
            if let handler = completion {
                handler(false)
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
        
        session.subscribe(toTopics: ["planter/row" : 1, "planter/status" : 2]) { (error, array) in
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
}
