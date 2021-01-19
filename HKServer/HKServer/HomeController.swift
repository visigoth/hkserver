//
//  HomeManagerDelegate.swift
//  hkserver
//
//  Created by Shaheen Gandhi on 1/18/21.
//

import Foundation
import HomeKit

class HomeController : NSObject, HMHomeManagerDelegate {
    var homeManager: HMHomeManager
    var ready: (HomeController) -> Void
    
    init(ready: @escaping (HomeController) -> Void) {
        self.homeManager = HMHomeManager()
        self.ready = ready
        super.init()
        
        homeManager.delegate = self
    }
    
    func homeManagerDidUpdateHomes(_ manager: HMHomeManager) {
        self.ready(self)
    }

    private func isAuthorized(status: HMHomeManagerAuthorizationStatus) -> Bool {
        return status.contains(.determined) && status.contains(.authorized)
    }
}
