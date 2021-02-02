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

class AppController : NSObject, ApplicationControllerProtocol {
    private var _serverUrl : URL?
    private var _userName: String = String.emptyString
    private var _passWord: String = String.emptyString

    let serialQueue = DispatchQueue(label: "com.queue.AppController.serial")
    var commController : CommunicationsProtocol?

    override init() {
        super.init()
    }
    
    convenience init(commsController : CommunicationsProtocol) {
        self.init()
        NotificationCenter.default.addObserver(self, selector: #selector(dataReceivedNotification(notification:)), name: .didReceiveData, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(onSessionDataReceivedNotification(notification:)), name: .sessionDataMessageNotification, object: nil)
        commController = commsController
    }

    func setCommsParameters(serverUrl: String, username: String, password: String) {
        self._serverUrl = URL(string: serverUrl)
        assert(self._serverUrl != nil, "Invalid URL String!")
        self._userName = username
        self._passWord = password
        
        initializeCommunicationsController(with: serverUrl, username: username, password: password)
    }

    var serverUrl: URL? {
        return _serverUrl
    }
    
    var userName: String {
        return _userName
    }
    var passWord: String {
        return _passWord
    }

    @objc func onSessionDataReceivedNotification(notification : Notification) {
        //        debugPrint("\(self.typeName):\(#function)")
        guard let sessionDataMessage = notification.userInfo?[userInfoSessionDataReceivedKey] as? Data else {
            assertionFailure("Failed to get data from notification")
            return
        }
        
        let decoder = JSONDecoder()
        guard let testData = try? decoder.decode(SessionData.self, from: sessionDataMessage) else {
            debugPrint("\(self.typeName):\(#function) - Error getting SessionData object")
            return
        }
        
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .newSessionDataRowNotification, object: self, userInfo: [userInfoPlotSessionDataKey : testData])
        }
        
    }
    
    @objc func dataReceivedNotification(notification : Notification) {
//        debugPrint("\(self.typeName):\(#function)")
        guard let plottedRowData = notification.userInfo?[userInfoDataReceivedKey] as? Data else {
            assertionFailure("Failed to get data from notification")
            return
        }
        
        var plottedRow : PlottedRowInfoProtocol?
        do {
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
    private func initializeCommunicationsController(with serverUrlString : String, username : String, password : String) {

        guard let serverUrl = URL(string: serverUrlString) else {
            return
        }
        self.commController?.connect(connectionUrl: serverUrl, completion: { (error) in
            guard let someError = error else {
                debugPrint("\(self.typeName):\(#function) - The connection was successful")
                return
            }
            debugPrint("\(self.typeName):\(#function) - Error connecting to server \(serverUrl): \(someError.localizedDescription)")
        })
    }
    
    private func initializePlottingManager() {
        
    }
}
