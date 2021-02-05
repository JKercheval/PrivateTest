//
//  DashboardViewModel.swift
//  Scratch
//
//  Created by Jeremy Kercheval on 1/11/21.
//

import Foundation

protocol DashboardViewModelProtocol {
    init(type : DisplayType)
    func onPlotNewRowReceived(notification : Notification)
    var value : String { get }
    var title : String { get }
    var unitOfMeasure : String { get }
}

protocol DashboardViewModelProtocolDelegate {
    func valueChanged(_ value : String)
}

class DashboardViewModel : NSObject, DashboardViewModelProtocol {
    
    var dashboardType : DisplayType = .none
    var delegate : DashboardViewModelProtocolDelegate?
    private var plottedRow : PlottedRowInfoProtocol?
    private var internalValue : String = String.emptyString
    
    override init() {
        super.init()
    }
    
    required convenience init(type : DisplayType) {
        self.init()
        dashboardType = type
        NotificationCenter.default.addObserver(self, selector: #selector(onPlotNewRowReceived(notification:)), name:.dashboardAlertNotification, object: nil)
    }
    
    @objc func onPlotNewRowReceived(notification : Notification) {
        guard let plottedRow = notification.userInfo?[userInfoPlottedRowKey] as? PlottedRowInfoProtocol else {
            debugPrint("No information to display")
            return
        }
        self.plottedRow = plottedRow
        if dashboardType == .speed {
            guard let speed = self.plottedRow?.speed else {
                return
            }
            delegate?.valueChanged(String(speed))
        }

        guard let rowValue = self.plottedRow?.value(for: 0, displayType: dashboardType),
              rowValue != -Float.greatestFiniteMagnitude else {
            return
        }
        let stringValue = rowValue.description
        delegate?.valueChanged(stringValue)
    }
    
    var value : String {
        if dashboardType == .speed {
            guard let speed = plottedRow?.speed else {
                return String.emptyString
            }
            return String(speed)
        }
        guard let rowValue = self.plottedRow?.value(for: 0, displayType: dashboardType),
              rowValue != -Float.greatestFiniteMagnitude else {
            return String.emptyString
        }
        return "\(rowValue)"
    }
    
    var title: String {
        return dashboardType.description
    }
    
    // TODO - we don't currently have this in the PlottedRow, but it is coming in the new model
    var unitOfMeasure: String {
        return "seeds1ac-1"
    }
    
}
