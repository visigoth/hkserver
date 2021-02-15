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
        return matches(filter: filterExpression(pattern: pattern))
    }

    func matchesExactly(nameOrUuid: String) -> Bool {
        if self.uuid == nameOrUuid {
            return true
        }
        if let name = self.filterableName {
            if name == nameOrUuid {
                return true
            }
        }
        return false
    }
}

func filterExpression(pattern: String?) -> NSRegularExpression? {
    var filter: NSRegularExpression?
    if let pattern = pattern {
        if pattern.count != 0 {
            filter = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive)
        }
    }
    return filter
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
extension HMLocationEvent : NameOrUuidFilterable, NoNameProperty {}
extension HMCalendarEvent : NameOrUuidFilterable, NoNameProperty {}
extension HMDurationEvent : NameOrUuidFilterable, NoNameProperty {}
extension HMSignificantTimeEvent : NameOrUuidFilterable, NoNameProperty {}
extension HMPresenceEvent : NameOrUuidFilterable, NoNameProperty {}
extension HMCharacteristicEvent : NameOrUuidFilterable, NoNameProperty {}
extension HMCharacteristicThresholdRangeEvent : NameOrUuidFilterable, NoNameProperty {}

let Weekdays : [Org_Hkserver_Weekday] = [
    .sunday,
    .monday,
    .tuesday,
    .wednesday,
    .thursday,
    .friday,
    .saturday,
]

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
        
        let transform = { HomeKitServiceProvider.roomInfo(home: home, room: $0) }
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
        guard let home = self.findHome(pattern: request.home) else {
            return context.eventLoop.makeFailedFuture(HomeKitServiceError.homeNotFound(pattern: request.home))
        }
        
        let transform = { HomeKitServiceProvider.accessoryInfo(accessory: $0) }
        let rooms = request.zoneFilter.count == 0 ? nil : home.zones.filter { $0.matches(pattern: request.zoneFilter) }.flatMap { $0.rooms }
        let accessoryInfos = home.accessories
            .filter { $0.matches(pattern: request.nameFilter) }
            .filter {
                guard let rooms = rooms else { return true }
                guard let room = $0.room else { return false } // Non-empty zone filter, so unassigned accessories do not match
                return rooms.contains(room)
            }
            .filter {
                guard let room = $0.room else { return request.roomFilter.count == 0 } // Matches when there is no room filter
                return room.matches(pattern: request.roomFilter)
            }
            .map { transform($0) }
        
        var response = Org_Hkserver_EnumerateAccessoriesResponse()
        response.accessories = accessoryInfos
        response.home.name = home.name
        response.home.uuid = home.uuid
        
        return context.eventLoop.makeSucceededFuture(response)
    }
    
    func enumerateServiceGroups(request: Org_Hkserver_EnumerateServiceGroupsRequest, context: StatusOnlyCallContext) -> EventLoopFuture<Org_Hkserver_EnumerateServiceGroupsResponse> {
        guard let home = self.findHome(pattern: request.home) else {
            return context.eventLoop.makeFailedFuture(HomeKitServiceError.homeNotFound(pattern: request.home))
        }

        let transform = { HomeKitServiceProvider.serviceGroupInformation(serviceGroup: $0) }
        let serviceGroups = home.serviceGroups
            .filter { $0.matches(pattern: request.nameFilter) }
            .map { transform($0) }

        var response = Org_Hkserver_EnumerateServiceGroupsResponse()
        response.home = HomeKitServiceProvider.nameUuidPair(obj: home)
        response.serviceGroups = serviceGroups
        return context.eventLoop.makeSucceededFuture(response)
    }

    func enumerateServices(request: Org_Hkserver_EnumerateServicesRequest, context: StatusOnlyCallContext) ->
    EventLoopFuture<Org_Hkserver_EnumerateServicesResponse> {
        guard let home = self.findHome(pattern: request.home) else {
            return context.eventLoop.makeFailedFuture(HomeKitServiceError.homeNotFound(pattern: request.home))
        }

        var services: [HMService]
        let typePatterns = request.types.compactMap { HomeKitServiceProvider.fromServiceType(serviceType: $0) }
        if typePatterns.count != 0 {
            services = home.servicesWithTypes(typePatterns) ?? []
        } else {
            services = home.accessories.flatMap { $0.services }
        }
        services = services
            .filter { $0.matches(pattern: request.nameFilter) }

        let serviceInfos = services
            .map { HomeKitServiceProvider.serviceInformation(service: $0) }

        var response = Org_Hkserver_EnumerateServicesResponse()
        response.home = HomeKitServiceProvider.nameUuidPair(obj: home)
        response.services = serviceInfos
        return context.eventLoop.makeSucceededFuture(response)
    }

    func enumerateActionSets(request: Org_Hkserver_EnumerateActionSetsRequest, context: StatusOnlyCallContext) -> EventLoopFuture<Org_Hkserver_EnumerateActionSetsResponse> {
        guard let home = self.findHome(pattern: request.home) else {
            return context.eventLoop.makeFailedFuture(HomeKitServiceError.homeNotFound(pattern: request.home))
        }
        
        let builtinActionSetTypes = [
            HMActionSetTypeSleep,
            HMActionSetTypeWakeUp,
            HMActionSetTypeHomeArrival,
            HMActionSetTypeUserDefined,
            HMActionSetTypeTriggerOwned,
            HMActionSetTypeHomeDeparture,
        ];
        let builtinActionSets = builtinActionSetTypes.compactMap { home.builtinActionSet(ofType: $0) }
        let actionSets = [builtinActionSets, home.actionSets].joined().reduce([String: HMActionSet]()) { (dict, actionSet) -> [String: HMActionSet] in
            var dict = dict
            dict[actionSet.uuid] = actionSet
            return dict
        }.map { $1 }
        let actionSetInfos = actionSets.map { HomeKitServiceProvider.actionSetInformation(actionSet: $0) }
        
        var response = Org_Hkserver_EnumerateActionSetsResponse()
        response.home = HomeKitServiceProvider.nameUuidPair(obj: home)
        response.actionSets = actionSetInfos
        return context.eventLoop.makeSucceededFuture(response)
    }
    
    func enumerateTriggers(request: Org_Hkserver_EnumerateTriggersRequest, context: StatusOnlyCallContext) ->
        EventLoopFuture<Org_Hkserver_EnumerateTriggersResponse> {
        guard let home = self.findHome(pattern: request.home) else {
            return context.eventLoop.makeFailedFuture(HomeKitServiceError.homeNotFound(pattern: request.home))
        }
        
        var triggers = home.triggers
            .filter { $0.matches(pattern: request.nameFilter) }
        if request.enabledFilter != .noFilter {
            triggers = triggers.filter {
                $0.isEnabled == (request.enabledFilter == .enabledOnly)
            }
        }
        if request.before != 0 {
            triggers = triggers.filter {
                guard let date = $0.lastFireDate else {
                    return false // never fired, so not "fired before" some date
                }
                
                return date.timeIntervalSince1970 <= Double(request.before)
            }
        }
        if request.after != 0 {
            triggers = triggers.filter {
                guard let date = $0.lastFireDate else {
                    return false // never fired, so not "fired after" some date
                }
                
                return date.timeIntervalSince1970 >= Double(request.after)
            }
        }
        
        let triggerInfos = triggers.map { HomeKitServiceProvider.triggerInformation(trigger: $0) }
        
        var response = Org_Hkserver_EnumerateTriggersResponse()
        response.home = HomeKitServiceProvider.nameUuidPair(obj: home)
        response.triggers = triggerInfos
        return context.eventLoop.makeSucceededFuture(response)
    }

    func addRemoveRoom(request: Org_Hkserver_AddRemoveRoomRequest, context: StatusOnlyCallContext) -> EventLoopFuture<Org_Hkserver_AddRemoveRoomResponse> {
        return context.eventLoop.makeFailedFuture(HomeKitServiceError.nyi)
    }
    
    func addRemoveZone(request: Org_Hkserver_AddRemoveZoneRequest, context: StatusOnlyCallContext) -> EventLoopFuture<Org_Hkserver_AddRemoveZoneResponse> {
        return context.eventLoop.makeFailedFuture(HomeKitServiceError.nyi)
    }
    
    func addRemoveServiceGroup(request: Org_Hkserver_AddRemoveServiceGroupRequest, context: StatusOnlyCallContext) -> EventLoopFuture<Org_Hkserver_AddRemoveServiceGroupResponse> {
        return context.eventLoop.makeFailedFuture(HomeKitServiceError.nyi)
    }
    
    func changeRoomZoneMembership(request: Org_Hkserver_ChangeRoomZoneMembershipRequest, context: StatusOnlyCallContext) -> EventLoopFuture<Org_Hkserver_ChangeRoomZoneMembershipResponse> {
        return context.eventLoop.makeFailedFuture(HomeKitServiceError.nyi)
    }
    
    func moveAccessoryToRoom(request: Org_Hkserver_MoveAccessoryToRoomRequest, context: StatusOnlyCallContext) -> EventLoopFuture<Org_Hkserver_MoveAccessoryToRoomResponse> {
        return context.eventLoop.makeFailedFuture(HomeKitServiceError.nyi)
    }
    
    func changeServiceGroupMembership(request: Org_Hkserver_ChangeServiceGroupMembershipRequest, context: StatusOnlyCallContext) -> EventLoopFuture<Org_Hkserver_ChangeServiceGroupMembershipResponse> {
        return context.eventLoop.makeFailedFuture(HomeKitServiceError.nyi)
    }
    
    func addRemoveActions(request: Org_Hkserver_AddRemoveActionSetRequest, context: StatusOnlyCallContext) -> EventLoopFuture<Org_Hkserver_AddRemoveActionSetResponse> {
        return context.eventLoop.makeFailedFuture(HomeKitServiceError.nyi)
    }
    
    func addRemoveTriggers(request: Org_Hkserver_AddRemoveTriggersRequest, context: StatusOnlyCallContext) -> EventLoopFuture<Org_Hkserver_AddRemoveTriggersResponse> {
        return context.eventLoop.makeFailedFuture(HomeKitServiceError.nyi)
    }
    
    func enableDisableTrigger(request: Org_Hkserver_EnableDisableTriggerRequest, context: StatusOnlyCallContext) -> EventLoopFuture<Org_Hkserver_EnableDisableTriggerResponse> {
        return context.eventLoop.makeFailedFuture(HomeKitServiceError.nyi)
    }
    
    func changeActionSetMembership(request: Org_Hkserver_ChangeActionSetMembershipRequest, context: StatusOnlyCallContext) -> EventLoopFuture<Org_Hkserver_ChangeActionSetMembershipResponse> {
        return context.eventLoop.makeFailedFuture(HomeKitServiceError.nyi)
    }
    
    func changeTriggerMembership(request: Org_Hkserver_ChangeTriggerMembershipRequest, context: StatusOnlyCallContext) -> EventLoopFuture<Org_Hkserver_ChangeTriggerMembershipResponse> {
        return context.eventLoop.makeFailedFuture(HomeKitServiceError.nyi)
    }
    
    func runActionSet(request: Org_Hkserver_RunActionSetRequest, context: StatusOnlyCallContext) -> EventLoopFuture<Org_Hkserver_RunActionSetResponse> {
        return context.eventLoop.makeFailedFuture(HomeKitServiceError.nyi)
    }
    
    func runTrigger(request: Org_Hkserver_RunTriggerRequest, context: StatusOnlyCallContext) -> EventLoopFuture<Org_Hkserver_RunTriggerResponse> {
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

    internal class func roomInfo(home: HMHome, room: HMRoom) -> Org_Hkserver_RoomInformation {
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
    
    internal class func accessoryInfo(accessory: HMAccessory) -> Org_Hkserver_AccessoryInformation {
        var ai = Org_Hkserver_AccessoryInformation()
        ai.name = accessory.name
        ai.uuid = accessory.uuid
        ai.category = HomeKitServiceProvider.accessoryCategory(category: accessory.category)
        if let room = accessory.room {
            ai.room = nameUuidPair(obj: room)
        }
        ai.profiles = accessory.profiles.map { HomeKitServiceProvider.profileInformation(profile: $0) }
        ai.isReachable = accessory.isReachable
        ai.isBlocked = accessory.isBlocked
        ai.supportsIdentify = accessory.supportsIdentify
        ai.services = accessory.services.map { HomeKitServiceProvider.serviceInformation(service: $0) }
        ai.isBridged = accessory.isBridged
        if let bridgedAccessories = accessory.uniqueIdentifiersForBridgedAccessories {
            ai.bridgedAccessoryUuids = bridgedAccessories.map { $0.uuidString }
        }
        if let firmwareVersion = accessory.firmwareVersion {
            ai.firmwareVersion = firmwareVersion
        }
        if let manufacturer = accessory.manufacturer {
            ai.manufacturer = manufacturer
        }
        if let model = accessory.model {
            ai.model = model
        }
        return ai
    }

    internal class func accessoryCategory(category: HMAccessoryCategory) -> Org_Hkserver_AccessoryInformation.Category {
        switch category.categoryType {
        case HMAccessoryCategoryTypeOther: return .other
        case HMAccessoryCategoryTypeSecuritySystem: return .securitySystem
        case HMAccessoryCategoryTypeBridge: return .bridge
        case HMAccessoryCategoryTypeDoor: return .door
        case HMAccessoryCategoryTypeDoorLock: return .doorLock
        case HMAccessoryCategoryTypeFan: return .fan
        case HMAccessoryCategoryTypeGarageDoorOpener: return .garageDoorOpener
        case HMAccessoryCategoryTypeIPCamera: return .ipCamera
        case HMAccessoryCategoryTypeLightbulb: return .lightBulb
        case HMAccessoryCategoryTypeOutlet: return .outlet
        case HMAccessoryCategoryTypeProgrammableSwitch: return .programmableSwitch
        case HMAccessoryCategoryTypeRangeExtender: return .rangeExtender
        case HMAccessoryCategoryTypeSensor: return .sensor
        case HMAccessoryCategoryTypeSwitch: return .switch
        case HMAccessoryCategoryTypeThermostat: return .thermostat
        case HMAccessoryCategoryTypeVideoDoorbell: return .videoDoorbell
        case HMAccessoryCategoryTypeWindow: return .window
        case HMAccessoryCategoryTypeWindowCovering: return .windowCovering
        case HMAccessoryCategoryTypeAirPurifier: return .airPurifier
        case HMAccessoryCategoryTypeAirHeater: return .airHeater
        case HMAccessoryCategoryTypeAirConditioner: return .airConditioner
        case HMAccessoryCategoryTypeAirHumidifier: return .airHumidifier
        case HMAccessoryCategoryTypeAirDehumidifier: return .airDehumidifier
        case HMAccessoryCategoryTypeSprinkler: return .sprinkler
        case HMAccessoryCategoryTypeFaucet: return .faucet
        case HMAccessoryCategoryTypeShowerHead: return .showerHead
        default:
            return .other
        }
    }
    
    internal class func profileInformation(profile: HMAccessoryProfile) -> Org_Hkserver_AccessoryProfileInformation {
        var pi = Org_Hkserver_AccessoryProfileInformation()
        pi.uuid = profile.uuid
        pi.services = profile.services.map { HomeKitServiceProvider.nameUuidPair(obj: $0) }
        if let networkConfigurationProfile = profile as? HMNetworkConfigurationProfile {
            pi.isNetworkAccessRestricted = networkConfigurationProfile.isNetworkAccessRestricted
        }
        return pi
    }
    
    internal class func serviceInformation(service: HMService) -> Org_Hkserver_ServiceInformation {
        var si = Org_Hkserver_ServiceInformation()
        si.name = service.name
        si.uuid = service.uuid
        si.serviceType = HomeKitServiceProvider.serviceType(serviceType: service.serviceType)
        si.characteristics = service.characteristics.map { HomeKitServiceProvider.characteristicInfo(characteristic: $0) }
        si.isPrimary = service.isPrimaryService
        si.isInteractive = service.isUserInteractive
        if let associatedServiceType = service.associatedServiceType {
            si.associatedServiceType = serviceType(serviceType: associatedServiceType)
        }
        if let linkedServices = service.linkedServices {
            si.linkedServices = linkedServices.map { nameUuidPair(obj: $0) }
        }
        if let accessory = service.accessory {
            si.accessory = nameUuidPair(obj: accessory)
        }
        return si
    }
    
    internal class func serviceGroupInformation(serviceGroup: HMServiceGroup) -> Org_Hkserver_ServiceGroupInformation {
        var sgi = Org_Hkserver_ServiceGroupInformation()
        sgi.name = serviceGroup.name
        sgi.uuid = serviceGroup.uuid
        sgi.services = serviceGroup.services.map { nameUuidPair(obj: $0) }
        return sgi
    }
    
    internal class func actionSetInformation(actionSet: HMActionSet) -> Org_Hkserver_ActionSetInformation {
        var asi = Org_Hkserver_ActionSetInformation()
        asi.name = actionSet.name
        asi.uuid = actionSet.uuid
        asi.actionSetType = actionSetType(actionSetType: actionSet.actionSetType)
        asi.isExecuting = actionSet.isExecuting
        asi.actions = actionSet.actions.map {
            if let action = $0 as? HMCharacteristicWriteAction<NSCopying> {
                return characteristicActionInformation(action: action)
            } else {
                return genericActionInformation(action: $0)
            }
        }
        return asi
    }
    
    internal class func actionSetType(actionSetType: String) -> Org_Hkserver_ActionSetInformation.ActionSetType {
        switch actionSetType {
        case HMActionSetTypeSleep: return .sleep
        case HMActionSetTypeWakeUp: return .wakeUp
        case HMActionSetTypeHomeDeparture: return .homeDeparture
        case HMActionSetTypeHomeArrival: return .homeArrival
        case HMActionSetTypeTriggerOwned: return .triggerOwned
        case HMActionSetTypeUserDefined: return .userDefined
        default:
            return .invalidActionSetType
        }
    }
    
    internal class func characteristicActionInformation(action: HMCharacteristicWriteAction<NSCopying>) -> Org_Hkserver_ActionSetInformation.Action {
        var ca = Org_Hkserver_ActionSetInformation.CharacteristicAction()
        ca.uuid = (action as HMAction).uuid
        ca.characteristic = characteristicInfo(characteristic: action.characteristic)
        let type = characteristicType(type: action.characteristic.characteristicType)
        let format = formatFromCharacteristicTypeAndMetadata(type: type, metadata: action.characteristic.metadata)
        ca.targetValue = valueFromCharacteristicValue(format: format, value: action.targetValue)!
        var a = Org_Hkserver_ActionSetInformation.Action()
        a.characteristicAction = ca
        return a
    }

    internal class func genericActionInformation(action: HMAction) -> Org_Hkserver_ActionSetInformation.Action {
        var ga = Org_Hkserver_ActionSetInformation.GenericAction()
        ga.uuid = action.uuid
        var a = Org_Hkserver_ActionSetInformation.Action()
        a.genericAction = ga
        return a
    }
    
    internal class func triggerInformation(trigger: HMTrigger) -> Org_Hkserver_TriggerInformation {
        var cti = Org_Hkserver_CommonTriggerInformation()
        cti.name = trigger.name
        cti.uuid = trigger.uuid
        cti.isEnabled = trigger.isEnabled
        if let lastFireDate = trigger.lastFireDate {
            cti.lastFireDate = UInt64(lastFireDate.timeIntervalSince1970)
        }
        cti.actionSets = trigger.actionSets.map { nameUuidPair(obj: $0) }

        var ti = Org_Hkserver_TriggerInformation()
        if let event = trigger as? HMEventTrigger {
            var eti = Org_Hkserver_EventTriggerInformation()
            eti.trigger = cti
            eti.activationState = triggerActivationState(activationState: event.triggerActivationState)
            eti.events = event.events.map { eventInformation(event: $0) }
            eti.endEvents = event.endEvents.map { eventInformation(event: $0) }
            if let recurrences = event.recurrences {
                eti.recurrences = recurrences.map { weekday(from: $0) }
            }
            eti.executesOnce = event.executeOnce
            ti.event = eti
        } else if let timer = trigger as? HMTimerTrigger {
            var tti = Org_Hkserver_TimerTriggerInformation()
            tti.trigger = cti
            tti.fireDate = UInt64(timer.fireDate.timeIntervalSince1970)
            if let calendar = timer.recurrenceCalendar, let recurrence = timer.recurrence {
                let next = calendar.date(byAdding: recurrence, to: timer.fireDate)
                tti.recurrence = UInt64(next?.timeIntervalSince(timer.fireDate) ?? 0.0)
            }
            ti.timer = tti
        }
        return ti
    }

    internal class func nameUuidPair(obj: NameOrUuidFilterable) -> Org_Hkserver_NameUuidPair {
        var nup = Org_Hkserver_NameUuidPair()
        nup.name = obj.filterableName ?? ""
        nup.uuid = obj.uuid
        return nup
    }
    
    internal class func serviceType(serviceType: String) -> Org_Hkserver_ServiceType {
        switch serviceType {
        case HMServiceTypeSwitch: return .switch
        case HMServiceTypeThermostat: return .thermostat
        case HMServiceTypeAccessoryInformation: return .accessoryInformation
        case HMServiceTypeOutlet: return .outlet
        case HMServiceTypeLockManagement: return .lockManagement
        case HMServiceTypeAirQualitySensor: return .airQualitySensor
        case HMServiceTypeCarbonDioxideSensor: return .carbonDioxideSensor
        case HMServiceTypeCarbonMonoxideSensor: return .carbonMonoxideSensor
        case HMServiceTypeContactSensor: return.contactSensor
        case HMServiceTypeDoor: return .door
        case HMServiceTypeHumiditySensor: return .humiditySensor
        case HMServiceTypeLeakSensor: return .leakSensor
        case HMServiceTypeLightSensor: return .lightSensor
        case HMServiceTypeMotionSensor: return .motionSensor
        case HMServiceTypeOccupancySensor: return .occupancySensor
        case HMServiceTypeSecuritySystem: return .securitySystem
        case HMServiceTypeStatefulProgrammableSwitch: return .statefulProgrammableSwitch
        case HMServiceTypeStatelessProgrammableSwitch: return .statelessProgrammableSwitch
        case HMServiceTypeSmokeSensor: return .smokeSensor
        case HMServiceTypeTemperatureSensor: return .temperatureSensor
        case HMServiceTypeWindow: return .window
        case HMServiceTypeWindowCovering: return .windowCovering
        case HMServiceTypeCameraRTPStreamManagement: return .cameraRtpStreamManagement
        case HMServiceTypeCameraControl: return .cameraControl
        case HMServiceTypeMicrophone: return .microphone
        case HMServiceTypeSpeaker: return .speaker
        case HMServiceTypeAirPurifier: return .airPurifier
        case HMServiceTypeFilterMaintenance: return .filterMaintenance
        case HMServiceTypeSlats: return .slats
        case HMServiceTypeLabel: return .label
        case HMServiceTypeIrrigationSystem: return .irrigationSystem
        case HMServiceTypeValve: return .valve
        case HMServiceTypeFaucet: return .faucet
        case HMServiceTypeFan: return .fan
        case HMServiceTypeGarageDoorOpener: return .garageDoorOpener
        case HMServiceTypeLightbulb: return .lightBulb
        case HMServiceTypeLockMechanism: return .lockMechanism
        case HMServiceTypeBattery: return .battery
        case HMServiceTypeVentilationFan: return .ventilationFan
        case HMServiceTypeHeaterCooler: return .heaterCooler
        case HMServiceTypeHumidifierDehumidifier: return .humidifierDehumidifier
        case HMServiceTypeDoorbell: return .doorbell
        default:
            return .invalidServiceType
        }
    }
    
    internal class func fromServiceType(serviceType: Org_Hkserver_ServiceType) -> String? {
        switch serviceType {
        case .switch: return HMServiceTypeSwitch
        case .thermostat: return HMServiceTypeThermostat
        case .accessoryInformation: return HMServiceTypeAccessoryInformation
        case .outlet: return HMServiceTypeOutlet
        case .lockManagement: return HMServiceTypeLockManagement
        case .airQualitySensor: return HMServiceTypeAirQualitySensor
        case .carbonDioxideSensor: return HMServiceTypeCarbonDioxideSensor
        case .carbonMonoxideSensor: return HMServiceTypeCarbonMonoxideSensor
        case .contactSensor: return HMServiceTypeContactSensor
        case .door: return HMServiceTypeDoor
        case .humiditySensor: return HMServiceTypeHumidifierDehumidifier
        case .leakSensor: return HMServiceTypeLeakSensor
        case .lightSensor: return HMServiceTypeLightSensor
        case .motionSensor: return HMServiceTypeMotionSensor
        case .occupancySensor: return HMServiceTypeOccupancySensor
        case .securitySystem: return HMServiceTypeSecuritySystem
        case .statefulProgrammableSwitch: return HMServiceTypeStatefulProgrammableSwitch
        case .statelessProgrammableSwitch: return HMServiceTypeStatelessProgrammableSwitch
        case .smokeSensor: return HMServiceTypeSmokeSensor
        case .temperatureSensor: return HMServiceTypeTemperatureSensor
        case .window: return HMServiceTypeWindow
        case .windowCovering: return HMServiceTypeWindowCovering
        case .cameraRtpStreamManagement: return HMServiceTypeCameraRTPStreamManagement
        case .cameraControl: return HMServiceTypeCameraControl
        case .microphone: return HMServiceTypeMicrophone
        case .speaker: return HMServiceTypeSpeaker
        case .airPurifier: return HMServiceTypeAirPurifier
        case .filterMaintenance: return HMServiceTypeFilterMaintenance
        case .slats: return HMServiceTypeSlats
        case .label: return HMServiceTypeLabel
        case .irrigationSystem: return HMServiceTypeIrrigationSystem
        case .valve: return HMServiceTypeValve
        case .faucet: return HMServiceTypeFaucet
        case .fan: return HMServiceTypeFan
        case .garageDoorOpener: return HMServiceTypeGarageDoorOpener
        case .lightBulb: return HMServiceTypeLightbulb
        case .lockMechanism: return HMServiceTypeLockMechanism
        case .battery: return HMServiceTypeBattery
        case .ventilationFan: return HMServiceTypeVentilationFan
        case .heaterCooler: return HMServiceTypeHeaterCooler
        case .humidifierDehumidifier: return HMServiceTypeHumidifierDehumidifier
        case .doorbell: return HMServiceTypeDoorbell
        case .invalidServiceType:
            fallthrough
        default:
            return nil
        }
    }
    
    internal class func characteristicInfo(characteristic: HMCharacteristic) -> Org_Hkserver_CharacteristicInformation {
        var ci = Org_Hkserver_CharacteristicInformation()
        ci.uuid = characteristic.uuid
        ci.description_p = characteristic.localizedDescription
        ci.properties = characteristic.properties.map { propertyFlag(propertyFlag: $0) }
        ci.characteristicType = characteristicType(type: characteristic.characteristicType)
        if let metadata = characteristic.metadata {
            ci.metadata = characteristicMetadata(type: ci.characteristicType, metadata: metadata)
        }
        if let value = characteristic.value {
            let format = formatFromCharacteristicTypeAndMetadata(type: ci.characteristicType, metadata: characteristic.metadata)
            ci.value = valueFromCharacteristicValue(format: format, value: value)!
        }
        return ci
    }
    
    internal class func propertyFlag(propertyFlag: String) -> Org_Hkserver_CharacteristicInformation.Property {
        switch propertyFlag {
        case HMCharacteristicPropertyHidden:
            return .hidden
        case HMCharacteristicPropertyReadable:
            return .readable
        case HMCharacteristicPropertyWritable:
            return .writable
        case HMCharacteristicPropertySupportsEventNotification:
            return .supportsEvent
        default:
            return .invalidProperty
        }
    }
    
    internal class func characteristicType(type: String) -> Org_Hkserver_CharacteristicInformation.CharacteristicType {
        switch type {
        case HMCharacteristicTypeTargetRelativeHumidity: return .targetRelativeHumidity
        case HMCharacteristicTypeIdentify: return .identify
        case HMCharacteristicTypeOutletInUse: return .outletInUse
        case HMCharacteristicTypeLogs: return .logs
        case HMCharacteristicTypeAudioFeedback: return .audioFeedback
        case HMCharacteristicTypeAdminOnlyAccess: return .adminOnlyAccess
        case HMCharacteristicTypeSecuritySystemAlarmType: return .securitySystemAlarmType
        case HMCharacteristicTypeMotionDetected: return .motionDetected
        case HMCharacteristicTypeLockMechanismLastKnownAction: return .lockMechanismLastKnownAction
        case HMCharacteristicTypeLockManagementControlPoint: return .lockManagementControlPoint
        case HMCharacteristicTypeLockManagementAutoSecureTimeout: return .lockManagementAutoSecureTimeout
        case HMCharacteristicTypeAirParticulateDensity: return .airParticulateDensity
        case HMCharacteristicTypeAirParticulateSize: return .airParticulateSize
        case HMCharacteristicTypeAirQuality: return .airQuality
        case HMCharacteristicTypeCarbonDioxideDetected: return .carbonDioxideDetected
        case HMCharacteristicTypeCarbonDioxideLevel: return .carbonDioxideLevel
        case HMCharacteristicTypeCarbonDioxidePeakLevel: return .carbonDioxidePeakLevel
        case HMCharacteristicTypeCarbonMonoxideDetected: return .carbonMonoxideDetected
        case HMCharacteristicTypeCarbonMonoxideLevel: return .carbonMonoxideLevel
        case HMCharacteristicTypeCarbonMonoxidePeakLevel: return .carbonMonoxidePeakLevel
        case HMCharacteristicTypeContactState: return .contactState
        case HMCharacteristicTypeCurrentHorizontalTilt: return .currentHorizontalTilt
        case HMCharacteristicTypeCurrentPosition: return .currentPosition
        case HMCharacteristicTypeCurrentSecuritySystemState: return .currentSecuritySystemState
        case HMCharacteristicTypeCurrentVerticalTilt: return .currentVerticalTilt
        case HMCharacteristicTypeHardwareVersion: return .hardwareVersion
        case HMCharacteristicTypeHoldPosition: return .holdPosition
        case HMCharacteristicTypeLeakDetected: return .leakDetected
        case HMCharacteristicTypeOccupancyDetected: return .occupancyDetected
        case HMCharacteristicTypeOutputState: return .outputState
        case HMCharacteristicTypePositionState: return .positionState
        case HMCharacteristicTypeSoftwareVersion: return .softwareVersion
        case HMCharacteristicTypeStatusActive: return .statusActive
        case HMCharacteristicTypeStatusFault: return .statusFault
        case HMCharacteristicTypeStatusJammed: return .statusJammed
        case HMCharacteristicTypeStatusTampered: return .statusTampered
        case HMCharacteristicTypeTargetHorizontalTilt: return .targetHorizontalTilt
        case HMCharacteristicTypeTargetSecuritySystemState: return .targetSecuritySystemState
        case HMCharacteristicTypeTargetPosition: return .targetPosition
        case HMCharacteristicTypeTargetVerticalTilt: return .targetVerticalTilt
        case HMCharacteristicTypeStreamingStatus: return .streamingStatus
        case HMCharacteristicTypeSetupStreamEndpoint: return .setupStreamEndpoint
        case HMCharacteristicTypeSupportedVideoStreamConfiguration: return .supportedVideoStreamConfiguration
        case HMCharacteristicTypeSupportedRTPConfiguration: return .supportedRtPconfiguration
        case HMCharacteristicTypeSelectedStreamConfiguration: return .selectedStreamConfiguration
        case HMCharacteristicTypeOpticalZoom: return .opticalZoom
        case HMCharacteristicTypeDigitalZoom: return .digitalZoom
        case HMCharacteristicTypeImageRotation: return .imageRotation
        case HMCharacteristicTypeImageMirroring: return .imageMirroring
        case HMCharacteristicTypeLabelNamespace: return .labelNamespace
        case HMCharacteristicTypeLabelIndex: return .labelIndex
        case HMCharacteristicTypeCurrentAirPurifierState: return .currentAirPurifierState
        case HMCharacteristicTypeTargetAirPurifierState: return .targetAirPurifierState
        case HMCharacteristicTypeCurrentSlatState: return .currentSlatState
        case HMCharacteristicTypeFilterChangeIndication: return .filterChangeIndication
        case HMCharacteristicTypeFilterLifeLevel: return .filterLifeLevel
        case HMCharacteristicTypeFilterResetChangeIndication: return .filterResetChangeIndication
        case HMCharacteristicTypeSlatType: return .slatType
        case HMCharacteristicTypeCurrentTilt: return .currentTilt
        case HMCharacteristicTypeTargetTilt: return .targetTilt
        case HMCharacteristicTypeOzoneDensity: return .ozoneDensity
        case HMCharacteristicTypeNitrogenDioxideDensity: return .nitrogenDioxideDensity
        case HMCharacteristicTypeSulphurDioxideDensity: return .sulphurDioxideDensity
        case HMCharacteristicTypePM2_5Density: return .pm25Density
        case HMCharacteristicTypePM10Density: return .pm10Density
        case HMCharacteristicTypeVolatileOrganicCompoundDensity: return .volatileOrganicCompoundDensity
        case HMCharacteristicTypeProgramMode: return .programMode
        case HMCharacteristicTypeInUse: return .inUse
        case HMCharacteristicTypeSetDuration: return .setDuration
        case HMCharacteristicTypeRemainingDuration: return .remainingDuration
        case HMCharacteristicTypeValveType: return .valveType
        case HMCharacteristicTypeBrightness: return .brightness
        case HMCharacteristicTypeCoolingThreshold: return .coolingThreshold
        case HMCharacteristicTypeCurrentDoorState: return .currentDoorState
        case HMCharacteristicTypeCurrentHeatingCooling: return .currentHeatingCooling
        case HMCharacteristicTypeCurrentRelativeHumidity: return .currentRelativeHumidity
        case HMCharacteristicTypeCurrentTemperature: return .currentTemperature
        case HMCharacteristicTypeHeatingThreshold: return .heatingThreshold
        case HMCharacteristicTypeHue: return .hue
        case HMCharacteristicTypeCurrentLockMechanismState: return .currentLockMechanismState
        case HMCharacteristicTypeTargetLockMechanismState: return .targetLockMechanismState
        case HMCharacteristicTypeName: return .name
        case HMCharacteristicTypeObstructionDetected: return .obstructionDetected
        case HMCharacteristicTypePowerState: return .powerState
        case HMCharacteristicTypeRotationDirection: return .rotationDirection
        case HMCharacteristicTypeRotationSpeed: return .rotationSpeed
        case HMCharacteristicTypeSaturation: return .saturation
        case HMCharacteristicTypeTargetDoorState: return .targetDoorState
        case HMCharacteristicTypeTargetHeatingCooling: return .targetHeatingCooling
        case HMCharacteristicTypeTargetTemperature: return .targetTemperature
        case HMCharacteristicTypeTemperatureUnits: return .temperatureUnits
        case HMCharacteristicTypeVersion: return .version
        case HMCharacteristicTypeBatteryLevel: return .batteryLevel
        case HMCharacteristicTypeCurrentLightLevel: return .currentLightLevel
        case HMCharacteristicTypeInputEvent: return .inputEvent
        case HMCharacteristicTypeSmokeDetected: return .smokeDetected
        case HMCharacteristicTypeStatusLowBattery: return .statusLowBattery
        case HMCharacteristicTypeChargingState: return .chargingState
        case HMCharacteristicTypeLockPhysicalControls: return .lockPhysicalControls
        case HMCharacteristicTypeCurrentFanState: return .currentFanState
        case HMCharacteristicTypeActive: return .active
        case HMCharacteristicTypeCurrentHeaterCoolerState: return .currentHeaterCoolerState
        case HMCharacteristicTypeTargetHeaterCoolerState: return .targetHeaterCoolerState
        case HMCharacteristicTypeCurrentHumidifierDehumidifierState: return .currentHumidifierDehumidifierState
        case HMCharacteristicTypeTargetHumidifierDehumidifierState: return .targetHumidifierDehumidifierState
        case HMCharacteristicTypeWaterLevel: return .waterLevel
        case HMCharacteristicTypeSwingMode: return .swingMode
        case HMCharacteristicTypeTargetFanState: return .targetFanState
        case HMCharacteristicTypeDehumidifierThreshold: return .dehumidifierThreshold
        case HMCharacteristicTypeHumidifierThreshold: return .humidifierThreshold
        case HMCharacteristicTypeColorTemperature: return .colorTemperature
        case HMCharacteristicTypeIsConfigured: return .isConfigured
        case HMCharacteristicTypeSupportedAudioStreamConfiguration: return .supportedAudioStreamConfiguration
        case HMCharacteristicTypeVolume: return .volume
        case HMCharacteristicTypeMute: return .mute
        case HMCharacteristicTypeNightVision: return .nightVision
        default:
            return .invalidCharacteristicType
        }
    }
    
    internal class func characteristicMetadata(type: Org_Hkserver_CharacteristicInformation.CharacteristicType, metadata: HMCharacteristicMetadata) -> Org_Hkserver_CharacteristicInformation.Metadata {
        let format = formatFromCharacteristicTypeAndMetadata(type: type, metadata: metadata)
        var md = Org_Hkserver_CharacteristicInformation.Metadata()
        if let manufacturerDescription = metadata.manufacturerDescription {
            md.manufacturerDescription = manufacturerDescription
        }
        if let validValues = metadata.validValues {
            md.validValues = validValues.map { numberFromNSNumber(format: format, number: $0)! }
        }
        if let minValue = metadata.minimumValue {
            md.minimumValue = numberFromNSNumber(format: format, number: minValue)!
        }
        if let maxValue = metadata.maximumValue {
            md.maximumValue = numberFromNSNumber(format: format, number: maxValue)!
        }
        if let stepValue = metadata.stepValue {
            md.stepValue = numberFromNSNumber(format: format, number: stepValue)!
        }
        if let maxLength = metadata.maxLength {
            md.maxLength = numberFromNSNumber(format: .int, number: maxLength)!
        }
        if let format = metadata.format {
            md.format = formatFromMetadataFormat(format: format)
        }
        if let units = metadata.units {
            md.units = characteristicUnits(units: units)
        }
        return md
    }
    
    internal class func numberFromNSNumber(format: Org_Hkserver_CharacteristicInformation.Format, number: NSNumber) -> Org_Hkserver_Number? {
        var n = Org_Hkserver_Number()
        switch format {
        case .bool: // = 1
            n.signedIntegerValue = number.boolValue ? 1 : 0
            break
        case .int: // = 2
            n.signedIntegerValue = Int64(number.intValue)
            break
        case .float: // = 3
            n.floatValue = number.floatValue
            break
        case .uint8: // = 7
            n.unsignedIntegerValue = UInt64(number.uint8Value)
            break
        case .uint16: // = 8
            n.unsignedIntegerValue = UInt64(number.uint16Value)
            break
        case .uint32: // = 9
            n.unsignedIntegerValue = UInt64(number.uint32Value)
            break
        case .uint64: // = 10
            n.unsignedIntegerValue = number.uint64Value
            break
        case .string: // = 4
            fallthrough
        case .array: // = 5
            fallthrough
        case .dictionary: // = 6
            fallthrough
        case .data: // = 11
            fallthrough
        case .tlv8: // = 12
            fallthrough
        default:
            return nil
        }
        return n
    }
    
    internal class func valueFromCharacteristicValue(format: Org_Hkserver_CharacteristicInformation.Format, value: Any) -> Org_Hkserver_Value? {
        var v = Org_Hkserver_Value()
        switch format {
        case .bool: // = 1
            v.boolValue = (value as! NSNumber).boolValue
            break
        case .int: // = 2
            fallthrough
        case .float: // = 3
            fallthrough
        case .uint8: // = 7
            fallthrough
        case .uint16: // = 8
            fallthrough
        case .uint32: // = 9
            fallthrough
        case .uint64: // = 10
            v.numberValue = numberFromNSNumber(format: format, number: value as! NSNumber)!
            break
        case .string: // = 4
            v.stringValue = value as! String
            break
        case .data: // = 11
            fallthrough
        case .tlv8: // = 12
            v.dataValue = value as! Data
            break
        case .array: // = 5
            fallthrough
        case .dictionary: // = 6
            // TODO: figure out arrays and dictionaries
            return nil
        default:
            return nil
        }
        return v
    }
    
    internal class func formatFromCharacteristicTypeAndMetadata(type: Org_Hkserver_CharacteristicInformation.CharacteristicType, metadata: HMCharacteristicMetadata?) -> Org_Hkserver_CharacteristicInformation.Format {
        if let format = metadata?.format {
            return formatFromMetadataFormat(format: format)
        }
        
        return formatFromCharacteristicType(type: type)
    }
    
    internal class func formatFromMetadataFormat(format: String) -> Org_Hkserver_CharacteristicInformation.Format {
        switch format {
        case HMCharacteristicMetadataFormatBool:
            return .bool
        case HMCharacteristicMetadataFormatInt:
            return .int
        case HMCharacteristicMetadataFormatFloat:
            return .float
        case HMCharacteristicMetadataFormatString:
            return .string
        case HMCharacteristicMetadataFormatArray:
            return .array
        case HMCharacteristicMetadataFormatDictionary:
            return .dictionary
        case HMCharacteristicMetadataFormatUInt8:
            return .uint8
        case HMCharacteristicMetadataFormatUInt16:
            return .uint16
        case HMCharacteristicMetadataFormatUInt32:
            return .uint32
        case HMCharacteristicMetadataFormatUInt64:
            return .uint64
        case HMCharacteristicMetadataFormatData:
            return .data
        case HMCharacteristicMetadataFormatTLV8:
            return .tlv8
        default:
            return .invalidFormat
        }
    }
    
    internal class func formatFromCharacteristicType(type: Org_Hkserver_CharacteristicInformation.CharacteristicType) -> Org_Hkserver_CharacteristicInformation.Format {
        switch type {
        case .targetRelativeHumidity:
            return .float
        case .identify:
            return .bool
        case .outletInUse:
            return .bool
        case .logs:
            return .tlv8
        case .audioFeedback:
            return .bool
        case .adminOnlyAccess:
            return .bool
        case .securitySystemAlarmType:
            return .uint8
        case .motionDetected:
            return .bool
        case .lockMechanismLastKnownAction:
            return .int
        case .lockManagementControlPoint:
            return .tlv8
        case .lockManagementAutoSecureTimeout:
            return .uint32
        case .airParticulateDensity:
            return .float
        case .airParticulateSize:
            return .int

        case .airQuality:
            return .int
        case .carbonDioxideDetected:
            return .uint8
        case .carbonDioxideLevel:
            return .float
        case .carbonDioxidePeakLevel:
            return .float
        case .carbonMonoxideDetected:
            return .uint8
        case .carbonMonoxideLevel:
            return .float
        case .carbonMonoxidePeakLevel:
            return .float
        case .contactState:
            return .uint8
        case .currentHorizontalTilt:
            return .float
        case .currentPosition:
            return .uint8
            
            
        case .currentSecuritySystemState:
            return .int
        case .currentVerticalTilt:
            return .float
        case .hardwareVersion:
            return .string
        case .holdPosition:
            return .bool
        case .leakDetected:
            return .uint8
        case .occupancyDetected:
            return .uint8
        case .outputState:
            return .int
        case .positionState:
            return .int
        case .softwareVersion:
            return .string
        case .statusActive:
            return .bool
        case .statusFault:
            return .uint8
        case .statusJammed:
            return .uint8
        case .statusTampered:
            return .uint8
        case .targetHorizontalTilt:
            return .float
        case .targetSecuritySystemState:
            return .int
        case .targetPosition:
            return .uint8
        case .targetVerticalTilt:
            return .float
        case .streamingStatus:
            return .tlv8
        case .setupStreamEndpoint:
            return .tlv8
        case .supportedVideoStreamConfiguration:
            return .tlv8
        case .supportedRtPconfiguration:
            return .tlv8
        case .selectedStreamConfiguration:
            return .tlv8
        case .opticalZoom:
            return .float
        case .digitalZoom:
            return .float
        case .imageRotation:
            return .float
        case .imageMirroring:
            return .bool
        case .labelNamespace:
            return .int
        case .labelIndex:
            return .int
        case .currentAirPurifierState:
            return .int
        case .targetAirPurifierState:
            return .int
        case .currentSlatState:
            return .int
        case .filterChangeIndication:
            return .int
        case .filterLifeLevel:
            return .int
        case .filterResetChangeIndication:
            return .bool
        case .slatType:
            return .int
        case .currentTilt:
            return .float
        case .targetTilt:
            return .float
        case .ozoneDensity:
            return .float
        case .nitrogenDioxideDensity:
            return .float
        case .sulphurDioxideDensity:
            return .float
        case .pm25Density:
            return .float
        case .pm10Density:
            return .float
        case .volatileOrganicCompoundDensity:
            return .float
        case .programMode:
            return .int
        case .inUse:
            return .int
        case .setDuration:
            return .int
        case .remainingDuration:
            return .int
        case .valveType:
            return .int
        case .brightness:
            return .int
        case .coolingThreshold:
            return .float
        case .currentDoorState:
            return .int
        case .currentHeatingCooling:
            return .int
        case .currentRelativeHumidity:
            return .float
        case .currentTemperature:
            return .float
        case .heatingThreshold:
            return .float
        case .hue:
            return .float
        case .currentLockMechanismState:
            return .int
        case .targetLockMechanismState:
            return .int
        case .name:
            return .string
        case .obstructionDetected:
            return .bool
        case .powerState:
            return .bool
        case .rotationDirection:
            return .int
        case .rotationSpeed:
            return .float
        case .saturation:
            return .float
        case .targetDoorState:
            return .int
        case .targetHeatingCooling:
            return .int
        case .targetTemperature:
            return .float
        case .temperatureUnits:
            return .int
        case .version:
            return .string
        case .batteryLevel:
            return .uint8
        case .currentLightLevel:
            return .float
        case .inputEvent:
            return .int
        case .smokeDetected:
            return .int
        case .statusLowBattery:
            return .int
        case .chargingState:
            return .int
        case .lockPhysicalControls:
            return .int
        case .currentFanState:
            return .int
        case .active:
            return .int
        case .currentHeaterCoolerState:
            return .int
        case .targetHeaterCoolerState:
            return .int
        case .currentHumidifierDehumidifierState:
            return .int
        case .targetHumidifierDehumidifierState:
            return .int
        case .waterLevel:
            return .float
        case .swingMode:
            return .int
        case .targetFanState:
            return .int
        case .dehumidifierThreshold:
            return .float
        case .humidifierThreshold:
            return .float
        case .colorTemperature:
            return .int
        case .isConfigured:
            return .int
        case .supportedAudioStreamConfiguration:
            return .tlv8
        case .volume:
            return .uint8
        case .mute:
            return .bool
        case .nightVision:
            return .bool
        case .invalidCharacteristicType:
            return .invalidFormat
        case .UNRECOGNIZED(_):
            return .invalidFormat
        }
    }
    
    internal class func characteristicUnits(units: String) -> Org_Hkserver_CharacteristicInformation.Units {
        switch units {
        case HMCharacteristicMetadataUnitsCelsius:
            return .celsius
        case HMCharacteristicMetadataUnitsFahrenheit:
            return .fahrenheit
        case HMCharacteristicMetadataUnitsPercentage:
            return .percentage
        case HMCharacteristicMetadataUnitsArcDegree:
            return .arcDegree
        case HMCharacteristicMetadataUnitsSeconds:
            return .seconds
        case HMCharacteristicMetadataUnitsLux:
            return .lux
        case HMCharacteristicMetadataUnitsPartsPerMillion:
            return .partsPerMillion
        case HMCharacteristicMetadataUnitsMicrogramsPerCubicMeter:
            return .microgramsPerCubicMeter
        default:
            return .invalidUnits
        }
    }
    
    internal class func triggerActivationState(activationState: HMEventTriggerActivationState) -> Org_Hkserver_EventTriggerInformation.ActivationState {
        switch activationState {
        case .disabled:
            return .eventTriggerDisabled
        case .disabledNoCompatibleHomeHub:
            return .eventTriggerDisabledNoCompatibleHomeHub
        case .disabledNoHomeHub:
            return .eventTriggerDisabledNoHomeHub
        case .disabledNoLocationServicesAuthorization:
            return .eventTriggerDisabledNoLocationServicesAuthorization
        case .enabled:
            return .eventTriggerEnabled
        @unknown default:
            return .invalidActivationState
        }
    }
    
    internal class func eventInformation(event: HMEvent) -> Org_Hkserver_EventInformation {
        var ei = Org_Hkserver_EventInformation()
        if let event = event as? HMLocationEvent {
            var le = Org_Hkserver_LocationEventInformation()
            le.uuid = event.uuid
            le.notifyOnEntry = event.region?.notifyOnEntry ?? false
            le.notifyOnExit = event.region?.notifyOnExit ?? false
            le.region = regionInformation(region: event.region) ?? Org_Hkserver_CircularRegion()
            ei.locationEvent = le
        } else if let event = event as? HMCalendarEvent {
            var ce = Org_Hkserver_CalendarEventInformation()
            let calendar = event.fireDateComponents.calendar ?? Calendar.current
            ce.uuid = event.uuid
            ce.fireDate = UInt64(calendar.date(from: event.fireDateComponents)?.timeIntervalSince1970 ?? 0.0)
            ei.calendarEvent = ce
        } else if let event = event as? HMSignificantTimeEvent {
            var ste = Org_Hkserver_SignificantTimeEventInformation()
            ste.uuid = event.uuid
            ste.significantEvent = significantEvent(significantEvent: event.significantEvent)
            if let offset = event.offset {
                let calendar = offset.calendar ?? Calendar.current
                ste.offset = UInt64(calendar.date(from: offset)?.timeIntervalSince1970 ?? 0.0)
            }
            ei.significantTimeEvent = ste
        } else if let event = event as? HMDurationEvent {
            var de = Org_Hkserver_DurationEventInformation()
            de.uuid = event.uuid
            de.duration = event.duration
            ei.durationEvent = de
        } else if let event = event as? HMCharacteristicEvent<NSCopying> {
            var ce = Org_Hkserver_CharacteristicEventInformation()
            ce.uuid = event.uuid
            ce.characteristic = nameUuidPair(obj: event.characteristic)
            if let triggerValue = event.triggerValue {
                let type = characteristicType(type: event.characteristic.characteristicType)
                ce.triggerValue = valueFromCharacteristicValue(format: formatFromCharacteristicTypeAndMetadata(type: type, metadata: event.characteristic.metadata), value: triggerValue)!
            }
            ei.characteristicEvent = ce
        } else if let event = event as? HMCharacteristicThresholdRangeEvent {
            var ctre = Org_Hkserver_CharacteristicThresholdRangeEventInformation()
            ctre.uuid = event.uuid
            ctre.characteristic = nameUuidPair(obj: event.characteristic)
            let type = characteristicType(type: event.characteristic.characteristicType)
            let format = formatFromCharacteristicTypeAndMetadata(type: type, metadata: event.characteristic.metadata)
            ctre.range = numberRange(format: format, numberRange: event.thresholdRange)
            ei.characteristicThresholdRangeEvent = ctre
        } else if let event = event as? HMPresenceEvent {
            var pe = Org_Hkserver_PresenceEventInformation()
            pe.uuid = event.uuid
            pe.presenceEvent = presenceEventType(presenceEventType: event.presenceEventType)
            pe.presenceUser = presenceEventUserType(presenceEventUserType: event.presenceUserType)
            ei.presenceEvent = pe
        }
        return ei
    }
    
    internal class func regionInformation(region: CLRegion?) -> Org_Hkserver_CircularRegion? {
        guard let region = region as? CLCircularRegion else {
            return nil
        }
        
        var cri = Org_Hkserver_CircularRegion()
        cri.center = coordinate2D(coords: region.center)
        cri.radius = region.radius
        return cri
    }
    
    internal class func coordinate2D(coords: CLLocationCoordinate2D) -> Org_Hkserver_Coordinate2D {
        var c2d = Org_Hkserver_Coordinate2D()
        c2d.latitude = coords.latitude
        c2d.longitude = coords.longitude
        return c2d
    }
    
    internal class func significantEvent(significantEvent: HMSignificantEvent) -> Org_Hkserver_SignificantEvent {
        switch significantEvent {
        case .sunrise:
            return .sunrise
        case .sunset:
            return .sunset
        default:
            return .invalidSignificantEvent
        }
    }
    
    internal class func numberRange(format: Org_Hkserver_CharacteristicInformation.Format, numberRange: HMNumberRange) -> Org_Hkserver_NumberRange {
        var nr = Org_Hkserver_NumberRange()
        if let minValue = numberRange.minValue {
            nr.minValue = numberFromNSNumber(format: format, number: minValue)!
        }
        if let maxValue = numberRange.maxValue {
            nr.maxValue = numberFromNSNumber(format: format, number: maxValue)!
        }
        return nr
    }
    
    internal class func presenceEventType(presenceEventType: HMPresenceEventType) -> Org_Hkserver_PresenceEventType {
        switch presenceEventType {
        case .everyEntry:
            return .everyEntry
        case .everyExit:
            return .everyExit
        case .firstEntry:
            return .firstEntry
        case .lastExit:
            return .lastExit
        default:
            return .invalidPresenceEventType
        }
    }
    
    internal class func presenceEventUserType(presenceEventUserType: HMPresenceEventUserType) -> Org_Hkserver_PresenceEventUserType {
        switch presenceEventUserType {
        case .currentUser:
            return .currentUser
        case .customUsers:
            return .customUsers
        case .homeUsers:
            return .homeUsers
        default:
            return .invalidPresenceEventUserType
        }
    }
    
    internal class func weekday(from: DateComponents) -> Org_Hkserver_Weekday {
        return Weekdays[from.weekday! - 1]
    }
}
