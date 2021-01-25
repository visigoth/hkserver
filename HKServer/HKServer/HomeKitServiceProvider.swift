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
    var code: GRPCStatus.Code
    var message: String?
    
    init(code: GRPCStatus.Code, message: String?) {
        self.code = code
        self.message = message
    }
    
    public static let nyi = HomeKitServiceError(code: .unimplemented, message: "NYI")
    
    public static func homeNotFound(pattern: String?) -> HomeKitServiceError {
        return HomeKitServiceError(code: .notFound, message: "Could not find a home matching '\(pattern ?? "nil")'")
    }
}

extension HomeKitServiceError : GRPCStatusTransformable {
    func makeGRPCStatus() -> GRPCStatus {
        return GRPCStatus(code: .unimplemented, message: self.message)
    }
}

class HomeKitServiceProvider : Org_Hkserver_HomeKitServiceProvider {
    public var homeManager: HMHomeManager

    init(homeManager: HMHomeManager) {
        self.homeManager = homeManager
    }
    
    internal func findHome(pattern: String?) -> HMHome? {
        guard let pattern = pattern else {
            return homeManager.primaryHome
        }

        if pattern.count == 0 {
            return homeManager.primaryHome
        }

        do {
            let filter = try NSRegularExpression(pattern: pattern, options: .caseInsensitive)
            return homeManager.homes.first { $0.matches(filter: filter) }
        } catch {
            return nil
        }
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
        guard let home = self.findHome(pattern: request.home) else {
            return context.eventLoop.makeFailedFuture(HomeKitServiceError.homeNotFound(pattern: request.home))
        }
        
        let roomInfos = home.rooms.map { (room: HMRoom) -> Org_Hkserver_RoomInformation in
            var ri = Org_Hkserver_RoomInformation()
            ri.name = room.name
            ri.uuid = room.uuid
            ri.home = home.name
            ri.accessories = room.accessories.map { (accessory: HMAccessory) -> Org_Hkserver_NameUuidPair in
                var pair = Org_Hkserver_NameUuidPair()
                pair.name = accessory.name
                pair.uuid = accessory.uuid
                return pair
            }
            return ri
        }
        
        var response = Org_Hkserver_EnumerateRoomsResponse()
        response.rooms = roomInfos
        return context.eventLoop.makeSucceededFuture(response)
    }
    
    func enumerateZones(request: Org_Hkserver_EnumerateZonesRequest, context: StatusOnlyCallContext) -> EventLoopFuture<Org_Hkserver_EnumerateZonesResponse> {
        return context.eventLoop.makeFailedFuture(HomeKitServiceError.nyi)
    }
    
    func enumerateAccessories(request: Org_Hkserver_EnumerateAccessoriesRequest, context: StatusOnlyCallContext) -> EventLoopFuture<Org_Hkserver_EnumerateAccessoriesResponse> {
        return context.eventLoop.makeFailedFuture(HomeKitServiceError.nyi)
    }
    
    func enumerateServiceGroups(request: Org_Hkserver_EnumerateServiceGroupsRequest, context: StatusOnlyCallContext) -> EventLoopFuture<Org_Hkserver_EnumerateServiceGroupsResponse> {
        return context.eventLoop.makeFailedFuture(HomeKitServiceError.nyi)
    }
    
    func enumerateActionSets(request: Org_Hkserver_EnumerateActionSetsRequest, context: StatusOnlyCallContext) -> EventLoopFuture<Org_Hkserver_EnumerateActionSetsResponse> {
        return context.eventLoop.makeFailedFuture(HomeKitServiceError.nyi)
    }
    
    func enumerateTriggers(request: Org_Hkserver_EnumerateTriggersRequest, context: StatusOnlyCallContext) -> EventLoopFuture<Org_Hkserver_EnumerateTriggersResponse> {
        return context.eventLoop.makeFailedFuture(HomeKitServiceError.nyi)
    }
}
