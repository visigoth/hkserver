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

    @Option(name: .shortAndLong, help: "Port to bind to. Default is 55123")
    var port: Int?

    mutating func run() throws {
        let server = HKServer(host: nil, port: port ?? 55123)
        server.run()
    }
}
