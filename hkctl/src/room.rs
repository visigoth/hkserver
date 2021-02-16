use clap::{ArgMatches};
use simple_error::{SimpleError, SimpleResult};
use std::boxed::Box;
use std::future::Future;
use std::pin::Pin;
use std::str::FromStr;
use tonic::transport::Channel;
use crate::hkservice::home_kit_service_client::HomeKitServiceClient;
use crate::hkservice::{AddRemoveRoomRequest, AddRemoveRoomResponse};

impl FromStr for crate::hkservice::Operation {
    type Err = SimpleError;

    fn from_str(s: &str) -> SimpleResult<Self> {
        match s {
            "add" => Ok(Self::Add),
            "rm" => Ok(Self::Remove),
            "remove" => Ok(Self::Remove),
            _ => Err(SimpleError::new("Unrecognized operation")),
        }
    }
}

fn print_response(response: &AddRemoveRoomResponse) {
    println!("Home: {}, Room {}", response.home.as_ref().unwrap().name, response.room.as_ref().unwrap().name);
}

async fn _run(matches: ArgMatches, mut client: HomeKitServiceClient<Channel>) -> Result<(), Box<dyn std::error::Error>> {
    let operation_string = matches.value_of("operation").unwrap();
    let request = AddRemoveRoomRequest {
        home: matches.value_of("home").unwrap_or("").to_string(),
        name: matches.value_of("name").unwrap_or("").to_string(),
        accessories: matches.values_of("accessories").map_or(vec![], |values| values.collect()).iter().map(|s| s.to_string()).collect(),
        operation: crate::hkservice::Operation::from_str(operation_string).unwrap() as i32,
    };
    let response = client.add_remove_room(request.clone()).await?.into_inner();
    print_response(&response);
    Ok(())
}

pub fn run(matches: ArgMatches, client: HomeKitServiceClient<Channel>) -> Pin<Box<dyn Future<Output = Result<(), Box<dyn std::error::Error>>>>> {
    Box::pin(_run(matches, client))
}
