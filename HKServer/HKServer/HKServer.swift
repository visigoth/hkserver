//
//  HKServer.swift
//  hkserver
//
//  Created by Shaheen Gandhi on 1/18/21.
//

import Foundation
import GRPC
import NIO

class HKServer : HomeControllerDelegate {
    var homeController: HomeController

    var eventLoopGroup: MultiThreadedEventLoopGroup

    var service: HomeKitServiceProvider

    var serverConfiguration: Server.Configuration

    var runLoopSource: CFRunLoopSource?
    var runLoop: RunLoop?

    init(host: String?, port: Int) {
        eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
        service = HomeKitServiceProvider()
        let target = BindTarget.hostAndPort(host ?? "127.0.0.1", port)
        serverConfiguration = Server.Configuration(target: target, eventLoopGroup: eventLoopGroup, serviceProviders: [service])
        homeController = HomeController()
        homeController.delegate = self
    }

    public func run() {
        var context: CFRunLoopSourceContext = CFRunLoopSourceContext()
        context.perform = { _ in }

        runLoop = RunLoop.current
        runLoopSource = CFRunLoopSourceCreate(nil, 0, &context)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, CFRunLoopMode.commonModes)

        RunLoop.current.run()

        CFRunLoopRemoveSource(CFRunLoopGetCurrent(), runLoopSource, CFRunLoopMode.commonModes)
        try! self.eventLoopGroup.syncShutdownGracefully()
    }

    // ============= HomeControllerDelegate ===============

    func isReady() {
        Server.start(configuration: serverConfiguration)
            .flatMap { $0.onClose }
            .whenComplete({_ -> Void in
                self.runLoop?.perform {
                    CFRunLoopStop(CFRunLoopGetCurrent())
                }
            })
    }
}
