use clap::{ArgMatches};
use std::boxed::Box;
use std::future::Future;
use std::pin::Pin;
use tonic::transport::Channel;
use crate::hkservice::home_kit_service_client::HomeKitServiceClient;
use crate::hkservice::{EnumerateServicesRequest, EnumerateServicesResponse, ServiceInformation, ServiceType, CharacteristicInformation};

fn servicetype_from_str(s: &str) -> ServiceType {
    match s {
        "LightBulb" => ServiceType::LightBulb,
        "LightSensor" => ServiceType::LightSensor,
        "Switch" => ServiceType::Switch,
        "Battery" => ServiceType::Battery,
        "Outlet" => ServiceType::Outlet,
        "StatefulProgrammableSwitch" => ServiceType::StatefulProgrammableSwitch,
        "StatelessProgrammableSwitch" => ServiceType::StatelessProgrammableSwitch,
        "AirPurifier" => ServiceType::AirPurifier,
        "AirQualitySensor" => ServiceType::AirQualitySensor,
        "CarbonDioxideSensor" => ServiceType::CarbonDioxideSensor,
        "CarbonMonoxideSensor" => ServiceType::CarbonMonoxideSensor,
        "SmokeSensor" => ServiceType::SmokeSensor,
        "HeaterCooler" => ServiceType::HeaterCooler,
        "TemperatureSensor" => ServiceType::TemperatureSensor,
        "Thermostat" => ServiceType::Thermostat,
        "Fan" => ServiceType::Fan,
        "FilterMaintenance" => ServiceType::FilterMaintenance,
        "HumidifierDehumidifier" => ServiceType::HumidifierDehumidifier,
        "HumiditySensor" => ServiceType::HumiditySensor,
        "VentilationFan" => ServiceType::VentilationFan,
        "Window" => ServiceType::Window,
        "WindowCovering" => ServiceType::WindowCovering,
        "Slats" => ServiceType::Slats,
        "Faucet" => ServiceType::Faucet,
        "Valve" => ServiceType::Valve,
        "IrrigationSystem" => ServiceType::IrrigationSystem,
        "LeakSensor" => ServiceType::LeakSensor,
        "Door" => ServiceType::Door,
        "Doorbell" => ServiceType::Doorbell,
        "GarageDoorOpener" => ServiceType::GarageDoorOpener,
        "LockManagement" => ServiceType::LockManagement,
        "LockMechanism" => ServiceType::LockMechanism,
        "MotionSensor" => ServiceType::MotionSensor,
        "OccupancySensor" => ServiceType::OccupancySensor,
        "SecuritySystem" => ServiceType::SecuritySystem,
        "ContactSensor" => ServiceType::ContactSensor,
        "CameraControl" => ServiceType::CameraControl,
        "CameraRtpStreamManagement" => ServiceType::CameraRtpStreamManagement,
        "Microphone" => ServiceType::Microphone,
        "Speaker" => ServiceType::Speaker,
        "Label" => ServiceType::Label,
        "AccessoryInformation " => ServiceType::AccessoryInformation,
        _ => ServiceType::InvalidServiceType,
    }
}

pub fn print_characteristic(c: &CharacteristicInformation, indent: usize) {
    let prefix = " ".repeat(indent);
    println!("{}Characteristic: {}", prefix, c.uuid);
    println!("{}  Description: {}", prefix, c.description);
    let properties = c.properties().map(|x| x.to_string()).collect::<Vec<String>>().join(", prefix,");
    println!("{}  Properties: {}", prefix, properties);
    println!("{}  Type: {}", prefix, c.characteristic_type());
    if let Some(ref metadata) = c.metadata {
        println!("{}  Metadata:", prefix);
        println!("{}    Manufacturer Description: {}", prefix, metadata.manufacturer_description);
        if metadata.valid_values.len() != 0 {
            println!("{}    Valid Values: ({})", prefix, metadata.valid_values.len());
            metadata.valid_values.iter().for_each(|v| {
                println!("{}      {}", prefix, v);
            });
        }
        if let Some(ref min_val) = metadata.minimum_value {
            println!("{}    Minimum: {}", prefix, min_val);
        }
        if let Some(ref max_val) = metadata.maximum_value {
            println!("{}    Maximum: {}", prefix, max_val);
        }
        if let Some(ref step_val) = metadata.step_value {
            println!("{}    Step: {}", prefix, step_val);
        }
        println!("{}    Format: {}", prefix, metadata.format());
        println!("{}    Units: {}", prefix, metadata.units());
    }
    if let Some(ref value) = c.value {
        println!("{}  Last Value: {}", prefix, value);
    }
}

pub fn print_service(service: &ServiceInformation, indent: usize) {
    let prefix = " ".repeat(indent);
    println!("{}Service: {}", prefix, service.name);
    println!("{}  UUID: {}", prefix, service.uuid);
    println!("{}  Is Primary: {}", prefix, service.is_primary);
    println!("{}  Is Interactive: {}", prefix, service.is_interactive);
    println!("{}  Service Type: {}", prefix, service.service_type());
    println!("{}  Associated Service Type: {}", prefix, service.associated_service_type);
    println!("{}  Characteristics: ({})", prefix, service.characteristics.len());
    service.characteristics.iter().for_each(|c| {
        print_characteristic(c, indent + 4);
    });
}

fn print_response(response: &EnumerateServicesResponse) {
    if let Some(ref home) = response.home {
        println!("Home: {}", home.name);
    }
    println!("Services: ({})", response.services.len());
    response.services.iter().for_each(|service| {
        print_service(service, 2);
    });
}

async fn _run(matches: ArgMatches, mut client: HomeKitServiceClient<Channel>) -> Result<(), Box<dyn std::error::Error>> {
    let response = client.enumerate_services(
        EnumerateServicesRequest {
            home: matches.value_of("home").unwrap_or("").to_string(),
            types: matches.values_of("type").map(
                |v| v
                    .map(|s| servicetype_from_str(s) as i32)
                    .collect()
            ).unwrap_or(vec![]),
            name_filter: matches.value_of("name").unwrap_or("").to_string(),
        }).await?.into_inner();
    print_response(&response);
    Ok(())
}

pub fn run(matches: ArgMatches, client: HomeKitServiceClient<Channel>) -> Pin<Box<dyn Future<Output = Result<(), Box<dyn std::error::Error>>>>> {
    Box::pin(_run(matches, client))
}
