//
//  DashboardViewModel.swift
//  Scratch
//
//  Created by Jeremy Kercheval on 1/11/21.
//

import Foundation

class DashboardViewModel : NSObject {
    
    var dashboardType : DashboardType = .none
    
    override init() {
        super.init()
    }
    convenience init(type : DashboardType) {
        self.init()
        dashboardType = type
        NotificationCenter.default.addObserver(self, selector: #selector(onPlotNewRowReceived(notification:)), name:.dashboardAlertNotification, object: nil)
    }
    
    @objc func onPlotNewRowReceived(notification : Notification) {
        guard let plottedRow = notification.userInfo?[userInfoPlottedRowKey] as? PlottedRowInfoProtocol else {
            debugPrint("No information to display")
            return
        }
        
    }
}
