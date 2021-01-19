//
//  HKServer.swift
//  hkserver
//
//  Created by Shaheen Gandhi on 1/18/21.
//

import Foundation

class HKServer {
    var homeController: HomeController
    
    init(address: String?, port: Int?) {
        homeController = HomeController(ready: { _ -> Void in
            print("READY")
        })
    }
    
    public func run() {
        RunLoop.main.run()
    }
}
