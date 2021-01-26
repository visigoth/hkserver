use clap::{ArgMatches};
use std::boxed::Box;
use std::future::Future;
use std::pin::Pin;
use tonic::transport::Channel;
use crate::hkservice::home_kit_service_client::HomeKitServiceClient;
use crate::hkservice::{EnumerateRoomsRequest, EnumerateRoomsResponse};

fn print_response(response: &EnumerateRoomsResponse) {
    if let Some(ref home) = &response.home {
        println!("Home: {}", home.name);
    }
    println!("Rooms:");
    response.rooms.iter().for_each(|room| {
        println!("  Room: {}", room.name);
        println!("    UUID:         {}", room.uuid);
        println!("    Accessories: ({})", room.accessories.len());
        room.accessories.iter().for_each(|accessory| {
            println!("      Accessory: {}", accessory.name);
            println!("        UUID: {}", accessory.uuid);
        });
    });
}

async fn _run(matches: ArgMatches, mut client: HomeKitServiceClient<Channel>) -> Result<(), Box<dyn std::error::Error>> {
    let response = client.enumerate_rooms(
        EnumerateRoomsRequest {
            home: matches.value_of("home").unwrap_or("").to_string(),
            name_filter: matches.value_of("name").unwrap_or("").to_string(),
        }).await?.into_inner();
    print_response(&response);
    Ok(())
}

pub fn run(matches: ArgMatches, client: HomeKitServiceClient<Channel>) -> Pin<Box<dyn Future<Output = Result<(), Box<dyn std::error::Error>>>>> {
    Box::pin(_run(matches, client))
}
