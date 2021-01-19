//
//  HomeManagerDelegate.swift
//  hkserver
//
//  Created by Shaheen Gandhi on 1/18/21.
//

import Foundation
import HomeKit

protocol HomeControllerDelegate : class {
    func isReady() -> Void
}

class HomeController : NSObject, HMHomeManagerDelegate {
    var homeManager: HMHomeManager
    public weak var delegate: HomeControllerDelegate?
    
    override init() {
        self.homeManager = HMHomeManager()
        super.init()
        homeManager.delegate = self
    }
    
    func homeManagerDidUpdateHomes(_ manager: HMHomeManager) {
        self.delegate?.isReady()
    }

    private func isAuthorized(status: HMHomeManagerAuthorizationStatus) -> Bool {
        return status.contains(.determined) && status.contains(.authorized)
    }
}
