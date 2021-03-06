//
//  PlottingManagerProtocol.swift
//  Scratch
//
//  Created by Jeremy Kercheval on 12/15/20.
//

import Foundation

protocol PlottingManagerDelegate {
    func connected(success : Bool)
}

protocol PlottingManagerProtocol {
    
    var currentDisplayType : DisplayType { get }
    var machineInformation : MachineInfoProtocol { get }
    
    func reset()    
}
