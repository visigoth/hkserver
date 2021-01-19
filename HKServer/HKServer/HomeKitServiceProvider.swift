//
//  HomeKitServiceProvider.swift
//  hkserver
//
//  Created by Shaheen Gandhi on 1/18/21.
//

import Foundation
import GRPC
import NIO

class HomeKitServiceProvider : Org_Hkserver_HomeKitServiceProvider {
    internal var interceptors: Org_Hkserver_HomeKitServiceServerInterceptorFactoryProtocol?
    
    func enumerateDevices(request: Org_Hkserver_EnumerateDevicesRequest, context: StatusOnlyCallContext) -> EventLoopFuture<Org_Hkserver_EnumerateDevicesResponse> {
        let response = Org_Hkserver_EnumerateDevicesResponse()
        return context.eventLoop.makeSucceededFuture(response)
    }
}
