use clap::{ArgMatches};
use tonic::transport::Channel;
use crate::hkservice::home_kit_service_client::HomeKitServiceClient;
use crate::hkservice::EnumerateHomesRequest;

pub async fn command(_matches: &ArgMatches, mut client: HomeKitServiceClient<Channel>) -> Result<(), Box<dyn std::error::Error>> {
    let response = client.enumerate_homes(
        EnumerateHomesRequest {
            name_filter: String::from("")
        }
    ).await?.into_inner();
    println!("RESPONSE={:?}", response);
    Ok(())
}
