import Foundation
import MQTTClient

// Set this to the IP Address of the machine running MQTT
let serverAddress = "192.168.86.29"

class MqttPlottingManager : NSObject, PlottingManagerProtocol {

    private var transport = MQTTCFSocketTransport()
    private var displayType : DisplayType = .singulation
    private var machineInfo : MachineInfoProtocol!
    fileprivate var mqttSession = MQTTSession()
    let serialQueue = DispatchQueue(label: "com.queue.plottingManager.serial")
    var plottedRowsArray : Array<PlottedRowImpl> = Array<PlottedRowImpl>()

    override init() {
        super.init()
        MQTTLog.setLogLevel(.error)
        NotificationCenter.default.addObserver(self, selector: #selector(onDidPlotRowRecieved(notification:)),
                                               name:.didPlotRowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(onDisplayTypeChanged(notification:)),
                                               name:.didChangeDisplayTypeNotification, object: nil)

        self.mqttSession?.delegate = self
        self.machineInfo = MachineInfoProtocolImpl(with: defaultMachineWidthMeters, rowCount: defaultRowCount)
        
        self.transport.host = serverAddress//
        self.transport.port = 1883
        self.mqttSession?.userName = "tester"
        self.mqttSession?.password = "tester"
        mqttSession?.transport = transport
    }
    
    func connect(completion: CompletionHandler?) {
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
    
    var currentDisplayType : DisplayType {
        return displayType
    }
    
    var machineInformation : MachineInfoProtocol {
        return self.machineInfo
    }

        
    /// This is called when a plotted row has been drawn to the canvas.
    /// - Parameter notification: Notification object containing the PlottedRowInfoProtocol
    @objc func onDidPlotRowRecieved(notification : Notification) {
        guard let plottedRow = notification.userInfo?[userInfoPlottedCoordinateKey] as? PlottedRowInfoProtocol else {
            assert(notification.userInfo != nil, "There was no userInfo dictionary passed")
            return
        }

        serialQueue.sync {
            self.plottedRowsArray.removeAll { (row) -> Bool in
                if (row.plottingCoordinate.latitude == plottedRow.plottingCoordinate.latitude) &&
                    (row.plottingCoordinate.longitude == plottedRow.plottingCoordinate.longitude) {
                    return true
                }
                return false
            }
        }
    }
    
    @objc func onDisplayTypeChanged(notification : Notification) {
        guard let type = notification.userInfo?[userInfoDisplayTypeKey] as? DisplayType else {
            assert(notification.userInfo != nil, "There was no userInfo dictionary passed")
            return
        }
        
        self.displayType = type
        NotificationCenter.default.post(name: .switchDisplayTypeNotification, object: self)
    }
    
    /// Called when we are resetting our plotting for any reason.
    func reset() {
        serialQueue.sync {
            self.plottedRowsArray.removeAll()
        }
    }

}

extension MqttPlottingManager : MQTTSessionDelegate {
    
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
            do {
                //            let str = String(decoding: messageData, as: UTF8.self)
                //            debugPrint("\(#function) \(messageTopic):\(str)")
                let baseRow = try JSONDecoder().decode(PlottedRowBase.self, from: messageData)
                let plottedRow = PlottedRowImpl(baseRow: baseRow)
                guard let previous = self.plottedRowsArray.last else {
                    self.plottedRowsArray.append(plottedRow)
                    return
                }
                previous.nextPlottedRow = plottedRow
                self.plottedRowsArray.append(plottedRow)
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .plotNewRow, object: self, userInfo: [userInfoPlottedRowKey : previous])
                }
            }
            catch {
                debugPrint("\(#function) \(error.localizedDescription)")
            }
            
        }
        
    }
}
