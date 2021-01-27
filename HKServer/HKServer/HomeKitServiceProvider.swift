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

protocol FilterableName {
    var filterableName: String? { get }
}

protocol NoNameProperty : FilterableName {
}

extension NoNameProperty {
    var filterableName: String? {
        get { return nil }
    }
}
protocol WithNameProperty : FilterableName {
    var name: String { get }
}

extension WithNameProperty {
    var filterableName: String? {
        get { return self.name }
    }
}

protocol NameOrUuidFilterable : FilterableName {
    var uuid: String { get }
    var uniqueIdentifier: UUID { get }
    func matches(filter: NSRegularExpression?) -> Bool
    func matches(pattern: String?) -> Bool
}

extension NameOrUuidFilterable {
    var uuid: String {
        get { return self.uniqueIdentifier.uuidString }
    }
    func matches(filter: NSRegularExpression?) -> Bool {
        guard let filter = filter else {
            return true
        }
        let uuid = self.uuid
        if let name = self.filterableName {
            let range = NSRange(location: 0, length: name.count)
            if filter.matches(in: name, range: range).count != 0 {
                return true
            }
        }
        let range = NSRange(location: 0, length: uuid.count)
        return filter.matches(in: uuid, range: range).count != 0
    }
    func matches(pattern: String?) -> Bool {
        var filter: NSRegularExpression?
        if let pattern = pattern {
            if pattern.count != 0 {
                filter = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive)
            }
        }
        return matches(filter: filter)
    }
}

extension HMHome : NameOrUuidFilterable, WithNameProperty {}
extension HMRoom : NameOrUuidFilterable, WithNameProperty {}
extension HMAccessory : NameOrUuidFilterable, WithNameProperty {}
extension HMAccessoryProfile : NameOrUuidFilterable, NoNameProperty {}
extension HMService : NameOrUuidFilterable, WithNameProperty {}
extension HMCharacteristic : NameOrUuidFilterable, NoNameProperty {}
extension HMZone : NameOrUuidFilterable, WithNameProperty {}
extension HMServiceGroup : NameOrUuidFilterable, WithNameProperty {}
extension HMActionSet : NameOrUuidFilterable, WithNameProperty {}
extension HMAction : NameOrUuidFilterable, NoNameProperty {}
extension HMTrigger : NameOrUuidFilterable, WithNameProperty {}

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

    // ========== Org_Hkserver_HomeKitServiceProvider ============

    internal var interceptors: Org_Hkserver_HomeKitServiceServerInterceptorFactoryProtocol?

    func enumerateHomes(request: Org_Hkserver_EnumerateHomesRequest, context: StatusOnlyCallContext) -> EventLoopFuture<Org_Hkserver_EnumerateHomesResponse> {
        let homes = homeManager.homes
        let homeInfos = homes
            .filter { $0.matches(pattern: request.nameFilter) }
            .map({(home: HMHome) -> Org_Hkserver_HomeInformation in
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
        
        let transform = { HomeKitServiceProvider.roomInfoFromRoom(home: home, room: $0) }
        var roomInfos : Array<Org_Hkserver_RoomInformation> = [transform(home.roomForEntireHome())]
        roomInfos.append(contentsOf: home.rooms
                            .filter { $0.matches(pattern: request.nameFilter) }
                            .map { transform($0) } )
        
        var response = Org_Hkserver_EnumerateRoomsResponse()
        response.rooms = roomInfos
        return context.eventLoop.makeSucceededFuture(response)
    }
    
    func enumerateZones(request: Org_Hkserver_EnumerateZonesRequest, context: StatusOnlyCallContext) -> EventLoopFuture<Org_Hkserver_EnumerateZonesResponse> {
        guard let home = self.findHome(pattern: request.home) else {
            return context.eventLoop.makeFailedFuture(HomeKitServiceError.homeNotFound(pattern: request.home))
        }
        
        let zoneInfos = home.zones
            .filter { $0.matches(pattern: request.nameFilter) }
            .map { (zone: HMZone) -> Org_Hkserver_ZoneInformation in
                var zi = Org_Hkserver_ZoneInformation()
                zi.name = zone.name
                zi.uuid = zone.uuid
                zi.rooms = zone.rooms.map { (room: HMRoom) -> Org_Hkserver_NameUuidPair in
                    var pair = Org_Hkserver_NameUuidPair()
                    pair.name = room.name
                    pair.uuid = room.uuid
                    return pair
                }
                return zi
            }
        
        var response = Org_Hkserver_EnumerateZonesResponse()
        response.zones = zoneInfos
        return context.eventLoop.makeSucceededFuture(response)
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

    // ============== Helpers ============

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

    internal class func roomInfoFromRoom(home: HMHome, room: HMRoom) -> Org_Hkserver_RoomInformation {
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
}
