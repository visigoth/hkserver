//
//  hkserverApp.swift
//  hkserver
//
//  Created by Shaheen Gandhi on 1/17/21.
//

import ArgumentParser

@main
struct HKServerCommand : ParsableCommand {
    @Flag(help: "Verbose logging")
    var verbose = false

    @Option(name: .shortAndLong, help: "Port to bind to. Default is 20000")
    var port: Int?

    mutating func run() throws {
        let port = self.port ?? 20000
        let server = HKServer(address: nil, port: port)
        server.run()
    }
}
