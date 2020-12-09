//
//  PlottingManager.swift
//  Scratch
//
//  Created by Jeremy Kercheval on 12/8/20.
//

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
    
    @objc func onDidPlotRowRecieved(notification : Notification) {
        guard let plottedRow = notification.object as? PlottedRowInfoProtocol else {
            assert(notification.object != nil, "There was no object passed")
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
    
    func reset() {
        serialQueue.sync {
            self.plottedRowsArray.removeAll()
        }
    }

}
