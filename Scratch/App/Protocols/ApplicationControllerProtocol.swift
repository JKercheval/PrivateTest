//
//  ApplicationControllerProtocol.swift
//  Scratch
//
//  Created by Jeremy Kercheval on 1/14/21.
//

import Foundation

protocol ApplicationControllerProtocol {
    var serverUrl : URL? { get }
    var userName : String { get }
    var passWord : String { get }

    func setCommsParameters(serverUrl : String, username : String, password : String)
}
