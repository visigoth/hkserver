use clap::{ArgMatches};
use std::boxed::Box;
use std::future::Future;
use std::pin::Pin;
use tonic::transport::Channel;
use crate::hkservice::home_kit_service_client::HomeKitServiceClient;
use crate::hkservice::{EnumerateServiceGroupsRequest, EnumerateServiceGroupsResponse};

fn print_response(response: &EnumerateServiceGroupsResponse) {
    if let Some(ref home) = response.home {
        println!("Home: {}", home.name);
    }
    println!("Service Groups: ({})", response.service_groups.len());
    response.service_groups.iter().for_each(|service_group| {
        println!("  Service Group: {}", service_group.name);
        println!("    UUID: {}", service_group.uuid);
        println!("    Services: ({})", service_group.services.len());
        service_group.services.iter().for_each(|service| {
            println!("      Service: {} ({})", service.name, service.uuid);
        });
    });
}

async fn _run(matches: ArgMatches, mut client: HomeKitServiceClient<Channel>) -> Result<(), Box<dyn std::error::Error>> {
    let response = client.enumerate_service_groups(
        EnumerateServiceGroupsRequest {
            home: matches.value_of("home").unwrap_or("").to_string(),
            name_filter: matches.value_of("name").unwrap_or("").to_string(),
        }).await?.into_inner();
    print_response(&response);
    Ok(())
}

pub fn run(matches: ArgMatches, client: HomeKitServiceClient<Channel>) -> Pin<Box<dyn Future<Output = Result<(), Box<dyn std::error::Error>>>>> {
    Box::pin(_run(matches, client))
}
