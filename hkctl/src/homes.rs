use clap::{ArgMatches};
use tonic::transport::Channel;
use crate::hkservice::home_kit_service_client::HomeKitServiceClient;

pub async fn command(matches: &ArgMatches<'_>, client: HomeKitServiceClient<Channel>) {
    
}
