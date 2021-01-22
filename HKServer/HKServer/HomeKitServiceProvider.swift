//
//  HomeKitServiceProvider.swift
//  hkserver
//
//  Created by Shaheen Gandhi on 1/18/21.
//

import Foundation
import GRPC
import HomeKit
import NIO

class HomeKitServiceProvider : Org_Hkserver_HomeKitServiceProvider {
    public var homeManager: HMHomeManager
    
    init(homeManager: HMHomeManager) {
        self.homeManager = homeManager
    }
    
    // ========== Org_Hkserver_HomeKitServiceProvider ============
    
    internal var interceptors: Org_Hkserver_HomeKitServiceServerInterceptorFactoryProtocol?

    func enumerateHomes(request: Org_Hkserver_EnumerateHomesRequest, context: StatusOnlyCallContext) -> EventLoopFuture<Org_Hkserver_EnumerateHomesResponse> {
        let homes = homeManager.homes
        let homeInfos = homes.map({(home: HMHome) -> Org_Hkserver_HomeInformation in
            var hi = Org_Hkserver_HomeInformation()
            hi.name = home.name
            return hi
        });
        
        var response = Org_Hkserver_EnumerateHomesResponse()
        response.homes = homeInfos
        return context.eventLoop.makeSucceededFuture(response)
    }
}
