import Foundation

protocol PlottingManagerProtocol {
    func reset()
}

class PlottingManager : PlottingManagerProtocol {
    
    let serialQueue = DispatchQueue(label: "com.queue.plottingManager.serial")
    var plottedRowsArray : Array<PlottedRowInfoProtocol> = Array<PlottedRowInfoProtocol>()

    init() {
        NotificationCenter.default.addObserver(self, selector: #selector(onNewPlottedRowRecieved(notification:)), name:.newPlottedRow, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(onDidPlotRowRecieved(notification:)), name:.didPlotRowNotification, object: nil)
    }
    
    /// This is called when we receive a new PlottedRowInfoProtocol from the system
    /// - Parameter notification: Notification object containing the PlottedRowInfoProtocol
    @objc func onNewPlottedRowRecieved(notification : Notification) {
        guard let plottedRow = notification.userInfo?[userInfoPlottedRowKey] as? PlottedRowInfoProtocol else {
            return
        }

        serialQueue.sync {
            guard var previous = self.plottedRowsArray.last else {
                self.plottedRowsArray.append(plottedRow)
                return
            }
            previous.nextPlottedRow = plottedRow
            self.plottedRowsArray.append(plottedRow)
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .plotNewRow, object: self, userInfo: [userInfoPlottedRowKey : previous])
            }
        }
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
    
    
    /// Called when we are resetting our plotting for any reason.
    func reset() {
        serialQueue.sync {
            self.plottedRowsArray.removeAll()
        }
    }

}
