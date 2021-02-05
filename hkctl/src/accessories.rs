use clap::ArgMatches;
use hex;
use std::boxed::Box;
use std::future::Future;
use std::pin::Pin;
use tonic::transport::Channel;
use crate::hkservice::home_kit_service_client::HomeKitServiceClient;
use crate::hkservice::{EnumerateAccessoriesRequest, EnumerateAccessoriesResponse};
use crate::hkservice::accessory_information::Category;
use crate::hkservice::ServiceType;
use crate::hkservice::characteristic_information::CharacteristicType;
use crate::hkservice::characteristic_information::Property as CharacteristicProperty;
use crate::hkservice::characteristic_information::Format as CharacteristicFormat;
use crate::hkservice::characteristic_information::Units as CharacteristicUnits;
use crate::hkservice::{Number, number::Value, Value as SampledValue, value::Value as SampledValueEnum};
use crate::services::print_service;

impl std::fmt::Display for Category {
    fn fmt(&self, f: &mut std::fmt::Formatter) -> std::fmt::Result {
        write!(f, "{:?}", self)
    }
}

impl std::fmt::Display for ServiceType {
    fn fmt(&self, f: &mut std::fmt::Formatter) -> std::fmt::Result {
        write!(f, "{:?}", self)
    }
}

impl std::fmt::Display for CharacteristicType {
    fn fmt(&self, f: &mut std::fmt::Formatter) -> std::fmt::Result {
        write!(f, "{:?}", self)
    }
}

impl std::fmt::Display for CharacteristicProperty {
    fn fmt(&self, f: &mut std::fmt::Formatter) -> std::fmt::Result {
        write!(f, "{:?}", self)
    }
}

impl std::fmt::Display for CharacteristicFormat {
    fn fmt(&self, f: &mut std::fmt::Formatter) -> std::fmt::Result {
        write!(f, "{:?}", self)
    }
}

impl std::fmt::Display for CharacteristicUnits {
    fn fmt(&self, f: &mut std::fmt::Formatter) -> std::fmt::Result {
        write!(f, "{:?}", self)
    }
}

impl std::fmt::Display for SampledValue {
    fn fmt(&self, f: &mut std::fmt::Formatter) -> std::fmt::Result {
        if let Some(ref value) = self.value {
            match value {
                SampledValueEnum::BoolValue(b) => write!(f, "{}", b),
                SampledValueEnum::StringValue(s) => write!(f, "{}", s),
                SampledValueEnum::NumberValue(n) => write!(f, "{}", n),
                SampledValueEnum::DataValue(d) => write!(f, "{{{}, b'{}'}}", d.len(), hex::encode(d)),
            }
        } else {
            write!(f, "<None>")
        }
    }
}

impl std::fmt::Display for Number {
    fn fmt(&self, f: &mut std::fmt::Formatter) -> std::fmt::Result {
        if let Some(ref value) = self.value {
            match value {
                Value::SignedIntegerValue(i) => write!(f, "{}", i),
                Value::UnsignedIntegerValue(i) => write!(f, "{}", i),
                Value::FloatValue(v) => write!(f, "{}", v),
                Value::DoubleValue(d) => write!(f, "{}", d),
            }
        } else {
            write!(f, "<None>")
        }
    }
}

fn print_response(response: &EnumerateAccessoriesResponse) {
    println!("Accessories: ({})", response.accessories.len());
    response.accessories.iter().for_each(|accessory| {
        println!("  Accessory: {}", accessory.name);
        if let Some(ref room) = &accessory.room {
            println!("    Room: {} ({})", room.name, room.uuid);
        } else {
            println!("    Room: None");
        }
        println!("    UUID: {}", accessory.uuid);
        println!("    Category: {}", accessory.category());
        println!("    Model: {}", accessory.model);
        println!("    Manufacturer: {}", accessory.manufacturer);
        println!("    Firmware Version: {}", accessory.firmware_version);
        println!("    Is Reachable: {}", accessory.is_reachable);
        println!("    Is Blocked: {}", accessory.is_blocked);
        println!("    Is Bridged: {}", accessory.is_bridged);
        println!("    Supports Identify: {}", accessory.supports_identify);
        println!("    Profiles: ({})", accessory.profiles.len());
        accessory.profiles.iter().for_each(|profile| {
            println!("      Profile:");
            println!("        UUID: {}", profile.uuid);
            println!("        Network Restricted: {}", profile.is_network_access_restricted);
            println!("        Services: ({})", profile.services.len());
            profile.services.iter().for_each(|service| {
                println!("          Service: {} ({})", service.name, service.uuid);
            });
        });
        println!("    Services: ({})", accessory.services.len());
        accessory.services.iter().for_each(|service| {
            print_service(service, 6);
        });
        if accessory.category() == Category::Bridge {
            println!("    Bridged Accessories: ({})", accessory.bridged_accessory_uuids.len());
            accessory.bridged_accessory_uuids.iter().for_each(|uuid| {
                println!("      UUID: {}", uuid);
            });
        }
    })
}

async fn _run(matches: ArgMatches, mut client: HomeKitServiceClient<Channel>) -> Result<(), Box<dyn std::error::Error>> {
    let response = client.enumerate_accessories(
        EnumerateAccessoriesRequest {
            home: matches.value_of("home").unwrap_or("").to_string(),
            zone_filter: matches.value_of("zone").unwrap_or("").to_string(),
            room_filter: matches.value_of("room").unwrap_or("").to_string(),
            name_filter: matches.value_of("name").unwrap_or("").to_string(),
    }).await?.into_inner();
    print_response(&response);
    Ok(())
}

pub fn run(matches: ArgMatches, client: HomeKitServiceClient<Channel>) -> Pin<Box<dyn Future<Output = Result<(), Box<dyn std::error::Error>>>>> {
    Box::pin(_run(matches, client))
}
