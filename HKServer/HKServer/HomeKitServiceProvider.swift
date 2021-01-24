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

protocol NameOrUuidFilterable {
    var name: String? { get }
    var uuid: String { get }
    var uniqueIdentifier: UUID { get }
    func matches(filter: NSRegularExpression?) -> Bool
}

extension NameOrUuidFilterable {
    var name: String? {
        get { return nil }
    }
    var uuid: String {
        get { return self.uniqueIdentifier.uuidString }
    }
    func matches(filter: NSRegularExpression?) -> Bool {
        guard let filter = filter else {
            return true
        }
        let uuid = self.uuid
        if let name = self.name {
            let range = NSRange(location: 0, length: name.count)
            if filter.matches(in: name, range: range).count != 0 {
                return true
            }
        }
        let range = NSRange(location: 0, length: uuid.count)
        return filter.matches(in: uuid, range: range).count != 0
    }
}

extension HMHome : NameOrUuidFilterable {}
extension HMRoom : NameOrUuidFilterable {}
extension HMAccessory : NameOrUuidFilterable {}
extension HMAccessoryProfile : NameOrUuidFilterable {}
extension HMService : NameOrUuidFilterable {}
extension HMCharacteristic : NameOrUuidFilterable {}
extension HMZone : NameOrUuidFilterable {}
extension HMServiceGroup : NameOrUuidFilterable {}
extension HMActionSet : NameOrUuidFilterable {}
extension HMAction : NameOrUuidFilterable {}
extension HMTrigger : NameOrUuidFilterable {}

struct HomeKitServiceError : Error {
    var message: String
    
    init(message: String) {
        self.message = message
    }
}

class HomeKitServiceProvider : Org_Hkserver_HomeKitServiceProvider {
    public var homeManager: HMHomeManager

    init(homeManager: HMHomeManager) {
        self.homeManager = homeManager
    }
    
    internal func findHome(pattern: String?) throws -> HMHome? {
        guard let pattern = pattern else {
            return homeManager.primaryHome
        }

        if pattern.count == 0 {
            return homeManager.primaryHome
        }

        let filter = try NSRegularExpression(pattern: pattern, options: .caseInsensitive)
        return homeManager.homes.first { $0.matches(filter: filter) }
    }

    // ========== Org_Hkserver_HomeKitServiceProvider ============

    internal var interceptors: Org_Hkserver_HomeKitServiceServerInterceptorFactoryProtocol?

    func enumerateHomes(request: Org_Hkserver_EnumerateHomesRequest, context: StatusOnlyCallContext) -> EventLoopFuture<Org_Hkserver_EnumerateHomesResponse> {
        let homes = homeManager.homes
        let homeInfos = homes.map({(home: HMHome) -> Org_Hkserver_HomeInformation in
            var hi = Org_Hkserver_HomeInformation()
            hi.name = home.name
            hi.isPrimary = home.isPrimary
            hi.uuid = home.uniqueIdentifier.uuidString
            switch home.homeHubState {
            case .connected:
                hi.hubState = Org_Hkserver_HomeInformation.HomeHubState.connected
            case .disconnected:
                hi.hubState = Org_Hkserver_HomeInformation.HomeHubState.disconnected
            case .notAvailable:
                hi.hubState = Org_Hkserver_HomeInformation.HomeHubState.notAvailable
            @unknown default:
                break
            }
            return hi
        });

        var response = Org_Hkserver_EnumerateHomesResponse()
        response.homes = homeInfos
        return context.eventLoop.makeSucceededFuture(response)
    }
    
    func enumerateRooms(request: Org_Hkserver_EnumerateRoomsRequest, context: StatusOnlyCallContext) -> EventLoopFuture<Org_Hkserver_EnumerateRoomsResponse> {
        return context.eventLoop.makeFailedFuture(HomeKitServiceError(message: "NYI"))
    }
    
    func enumerateZones(request: Org_Hkserver_EnumerateZonesRequest, context: StatusOnlyCallContext) -> EventLoopFuture<Org_Hkserver_EnumerateZonesResponse> {
        return context.eventLoop.makeFailedFuture(HomeKitServiceError(message: "NYI"))
    }
    
    func enumerateAccessories(request: Org_Hkserver_EnumerateAccessoriesRequest, context: StatusOnlyCallContext) -> EventLoopFuture<Org_Hkserver_EnumerateAccessoriesResponse> {
        return context.eventLoop.makeFailedFuture(HomeKitServiceError(message: "NYI"))
    }
    
    func enumerateServiceGroups(request: Org_Hkserver_EnumerateServiceGroupsRequest, context: StatusOnlyCallContext) -> EventLoopFuture<Org_Hkserver_EnumerateServiceGroupsResponse> {
        return context.eventLoop.makeFailedFuture(HomeKitServiceError(message: "NYI"))
    }
    
    func enumerateActionSets(request: Org_Hkserver_EnumerateActionSetsRequest, context: StatusOnlyCallContext) -> EventLoopFuture<Org_Hkserver_EnumerateActionSetsResponse> {
        return context.eventLoop.makeFailedFuture(HomeKitServiceError(message: "NYI"))
    }
    
    func enumerateTriggers(request: Org_Hkserver_EnumerateTriggersRequest, context: StatusOnlyCallContext) -> EventLoopFuture<Org_Hkserver_EnumerateTriggersResponse> {
        return context.eventLoop.makeFailedFuture(HomeKitServiceError(message: "NYI"))
    }
}
