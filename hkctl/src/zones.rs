use clap::ArgMatches;
use std::boxed::Box;
use std::future::Future;
use std::pin::Pin;
use tonic::transport::Channel;
use crate::hkservice::home_kit_service_client::HomeKitServiceClient;
use crate::hkservice::{EnumerateZonesRequest, EnumerateZonesResponse};

fn print_response(response: &EnumerateZonesResponse) {
    println!("Zones ({}):", response.zones.len());
    response.zones.iter().for_each(|zone| {
        println!("  Zone: {}", zone.name);
        println!("    UUID: {}", zone.uuid);
        println!("    Rooms:");
        zone.rooms.iter().for_each(|room| {
            println!("      Room: {} ({})", room.name, room.uuid);
        });
    });
}

async fn _run(matches: ArgMatches, mut client: HomeKitServiceClient<Channel>) -> Result<(), Box<dyn std::error::Error>> {
    let response = client.enumerate_zones(
        EnumerateZonesRequest {
            home: matches.value_of("home").unwrap_or("").to_string(),
            room_filter: matches.value_of("room").unwrap_or("").to_string(),
            name_filter: matches.value_of("name").unwrap_or("").to_string(),
    }).await?.into_inner();
    print_response(&response);
    Ok(())
}

pub fn run(matches: ArgMatches, client: HomeKitServiceClient<Channel>) -> Pin<Box<dyn Future<Output = Result<(), Box<dyn std::error::Error>>>>> {
    Box::pin(_run(matches, client))
}
