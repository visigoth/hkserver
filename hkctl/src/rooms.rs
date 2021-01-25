use clap::{ArgMatches};
use std::boxed::Box;
use std::future::Future;
use std::pin::Pin;
use tonic::transport::Channel;
use crate::hkservice::home_kit_service_client::HomeKitServiceClient;
use crate::hkservice::{EnumerateRoomsRequest, EnumerateRoomsResponse};

async fn _run(matches: ArgMatches, mut client: HomeKitServiceClient<Channel>) -> Result<(), Box<dyn std::error::Error>> {
    let response = client.enumerate_rooms(
        EnumerateRoomsRequest {
            home: matches.value_of("home").unwrap_or("").to_string(),
            name_filter: "".to_string(),
        }).await?.into_inner();
    Ok(())
}

pub fn run(matches: ArgMatches, client: HomeKitServiceClient<Channel>) -> Pin<Box<dyn Future<Output = Result<(), Box<dyn std::error::Error>>>>> {
    Box::pin(_run(matches, client))
}
