//
//  AppController.swift
//  Scratch
//
//  Created by Jeremy Kercheval on 1/12/21.
//

import Foundation
import GLKit

enum DashboardType : UInt, CaseIterable, Codable {
    case none
    case singulation
    case rideQuality
    case downforce
    case speed
}

let DashboardUpdateTime : TimeInterval = 1.0 // in seconds

extension AppController: NameDescribable {}

class AppController : NSObject {
    var plottedRowsArray : Array<PlottedRowImpl> = Array<PlottedRowImpl>()
    let serialQueue = DispatchQueue(label: "com.queue.AppController.serial")
    var commController : CommunicationsProtocol?

    override init() {
        super.init()
        
        NotificationCenter.default.addObserver(self, selector: #selector(dataReceivedNotification(notification:)), name: .didReceiveData, object: nil)
        
        initializeCommunicationsController()
    }
    
    @objc func dataReceivedNotification(notification : Notification) {
        debugPrint("\(self.typeName):\(#function)")
        guard let plottedRowData = notification.userInfo?[userInfoDataReceivedKey] as? Data else {
            assertionFailure("Failed to get data from notification")
            return
        }
        
        var plottedRow : PlottedRowInfoProtocol?
        do {
            //            let str = String(decoding: messageData, as: UTF8.self)
            //            debugPrint("\(#function) \(messageTopic):\(str)")
            let baseRow = try JSONDecoder().decode(PlottedRowBase.self, from: plottedRowData)
            plottedRow = PlottedRowImpl(baseRow: baseRow)
        }
        catch {
            debugPrint("\(#function) \(error.localizedDescription)")
            return
        }
        
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .newPlottedRow, object: self, userInfo: [userInfoPlottedRowKey : plottedRow!])
        }
        
        sendDashboardAlertNotification(plottedRow: plottedRow!)
        // Send to storage
    }
    
    private lazy var elapsedTime : TimeInterval = {
        // Do this once
        let elapsed = CACurrentMediaTime()
        return elapsed
    }()

    func sendDashboardAlertNotification(plottedRow : PlottedRowInfoProtocol) {
        let currentTime : TimeInterval  = CACurrentMediaTime()
        // at most we want to post this once a second.
        if (((currentTime - elapsedTime) >= DashboardUpdateTime)) {
            debugPrint("\(self.typeName):\(#function) - sending dashboard info")

            DispatchQueue.main.async {
                let notification = Notification(name: .dashboardAlertNotification, object: self, userInfo: nil)
                NotificationQueue.default.enqueue(notification, postingStyle: .whenIdle, coalesceMask: .onName, forModes: nil)
            }
            elapsedTime = CACurrentMediaTime();
        }

    }
}

// Initializers
extension AppController {
  
    /// Initializes the communications manager.
    private func initializeCommunicationsController() {
        commController = CommunicationsController()
        guard let url = URL(string: mqttServerAddress) else {
            return
        }
        commController?.connect(connectionUrl: url, completion: { (success) in
            debugPrint("\(self.typeName):\(#function) : Connected")
        })
    }
    
    private func initializePlottingManager() {
        
    }
}
