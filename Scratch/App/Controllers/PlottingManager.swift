import Foundation
import MQTTClient

// Set this to the IP Address of the machine running MQTT

class PlottingManager : NSObject, PlottingManagerProtocol {

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
        NotificationCenter.default.addObserver(self, selector: #selector(onNewRowRecieved(notification:)), name: .newPlottedRow, object: nil)

        self.machineInfo = MachineInfoProtocolImpl(with: defaultMachineWidthMeters, rowCount: defaultRowCount)
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
    
    @objc func onNewRowRecieved(notification : Notification) {
        guard let plottedRow = notification.userInfo?[userInfoPlottedRowKey] as? PlottedRowImpl else {
            assert(notification.userInfo != nil, "There was no userInfo dictionary passed")
            return
        }
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
    
    /// Called when we are resetting our plotting for any reason.
    func reset() {
        serialQueue.sync {
            self.plottedRowsArray.removeAll()
        }
    }

}
