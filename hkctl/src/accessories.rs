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
use crate::hkservice::{Number, number::Value, characteristic_information::value::Value as SampledValue};
use std::vec::Vec;

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

impl std::fmt::Display for crate::hkservice::characteristic_information::Value {
    fn fmt(&self, f: &mut std::fmt::Formatter) -> std::fmt::Result {
        if let Some(ref value) = self.value {
            match value {
                SampledValue::BoolValue(b) => write!(f, "{}", b),
                SampledValue::StringValue(s) => write!(f, "{}", s),
                SampledValue::NumberValue(n) => write!(f, "{}", n),
                SampledValue::DataValue(d) => write!(f, "{{{}, b'{}'}}", d.len(), hex::encode(d)),
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
            println!("      Service: {}", service.name);
            println!("        UUID: {}", service.uuid);
            println!("        Is Primary: {}", service.is_primary);
            println!("        Is Interactive: {}", service.is_interactive);
            println!("        Service Type: {}", service.service_type());
            println!("        Associated Service Type: {}", service.associated_service_type);
            println!("        Characteristics: ({})", service.characteristics.len());
            service.characteristics.iter().for_each(|c| {
                println!("          Characteristic: {}", c.uuid);
                println!("            Description: {}", c.description);
                let properties = c.properties().map(|x| x.to_string()).collect::<Vec<String>>().join(",");
                println!("            Properties: {}", properties);
                println!("            Type: {}", c.characteristic_type());
                if let Some(ref metadata) = c.metadata {
                    println!("            Metadata:");
                    println!("              Manufacturer Description: {}", metadata.manufacturer_description);
                    if metadata.valid_values.len() != 0 {
                        println!("              Valid Values: ({})", metadata.valid_values.len());
                        metadata.valid_values.iter().for_each(|v| {
                            println!("                {}", v);
                        });
                    }
                    if let Some(ref min_val) = metadata.minimum_value {
                        println!("              Minimum: {}", min_val);
                    }
                    if let Some(ref max_val) = metadata.maximum_value {
                        println!("              Maximum: {}", max_val);
                    }
                    if let Some(ref step_val) = metadata.step_value {
                        println!("              Step: {}", step_val);
                    }
                    println!("              Format: {}", metadata.format());
                    println!("              Units: {}", metadata.units());
                }
                if let Some(ref value) = c.value {
                    println!("            Last Value: {}", value);
                }
            });
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
