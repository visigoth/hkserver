use clap::{ArgMatches};
use tonic::transport::Channel;
use crate::hkservice::home_kit_service_client::HomeKitServiceClient;
use crate::hkservice::{EnumerateHomesRequest, EnumerateHomesResponse};
use crate::hkservice::home_information::HomeHubState;

fn print_response(response: &EnumerateHomesResponse) {
    response.homes.iter().for_each(|home| {
        let primary = if home.is_primary { " (Primary)" } else { "" };
        let hub_state = match HomeHubState::from_i32(home.hub_state).unwrap() {
            HomeHubState::Connected => "Connected",
            HomeHubState::Disconnected => "Disconnected",
            HomeHubState::NotAvailable => "Not Available",
        };
        println!("Home: {}{}", home.name, primary);
        println!("  Hub State: {}", hub_state);
    });
}

pub async fn command(_matches: &ArgMatches, mut client: HomeKitServiceClient<Channel>) -> Result<(), Box<dyn std::error::Error>> {
    let response = client.enumerate_homes(
        EnumerateHomesRequest {
            name_filter: String::from("")
        }
    ).await?.into_inner();
    print_response(&response);
    Ok(())
}
