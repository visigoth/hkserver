//
//  hkserverApp.swift
//  hkserver
//
//  Created by Shaheen Gandhi on 1/17/21.
//

import ArgumentParser

@main
struct hkserverApp : ParsableCommand {
    @Flag(help: "Verbose logging")
    var verbose = false

    @Option(name: .shortAndLong, help: "Port to bind to. Default is 20000")
    var port: Int?

    mutating func run() throws {
        port = port ?? 20000
    }
}
