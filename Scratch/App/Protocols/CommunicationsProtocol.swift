//
//  CommunicationsProtocol.swift
//  Scratch
//
//  Created by Jeremy Kercheval on 1/12/21.
//

import Foundation

protocol CommunicationsProtocolDelegate {
    func didConnect(controller : CommunicationsProtocol)
    func didDisconnect(controller : CommunicationsProtocol)
    func retryDelay(controller : CommunicationsProtocol) -> TimeInterval
    func shouldRetryConnection(controller : CommunicationsProtocol) -> Bool
}

protocol CommunicationsProtocol {
    func connect(connectionUrl : URL, completion : CompletionHandler?)
    func disconnect()
}
