use clap::{ArgMatches};
use std::boxed::Box;
use std::future::Future;
use std::pin::Pin;
use tonic::transport::Channel;
use crate::hkservice::home_kit_service_client::HomeKitServiceClient;
use crate::hkservice::{EnumerateHomesRequest, EnumerateHomesResponse};
use crate::hkservice::home_information::HomeHubState;

fn print_response(response: &EnumerateHomesResponse) {
    response.homes.iter().for_each(|home| {
        let primary = if home.is_primary { " (Primary)" } else { "" };
        let hub_state = match HomeHubState::from_i32(home.hub_state).unwrap() {
            HomeHubState::InvalidHomeHubState => "Unknown",
            HomeHubState::Connected => "Connected",
            HomeHubState::Disconnected => "Disconnected",
            HomeHubState::NotAvailable => "Not Available",
        };
        println!("Home: {}{}", home.name, primary);
        println!("  UUID:      {}", home.uuid);
        println!("  Hub State: {}", hub_state);
    });
}

async fn _run(_matches: ArgMatches, mut client: HomeKitServiceClient<Channel>) -> Result<(), Box<dyn std::error::Error>> {
    let response = client.enumerate_homes(
        EnumerateHomesRequest {
            name_filter: String::from("")
        }
    ).await?.into_inner();
    print_response(&response);
    Ok(())
}

pub fn run(matches: ArgMatches, client: HomeKitServiceClient<Channel>) -> Pin<Box<dyn Future<Output = Result<(), Box<dyn std::error::Error>>>>> {
    Box::pin(_run(matches, client))
}
