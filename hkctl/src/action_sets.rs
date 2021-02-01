use clap::{ArgMatches};
use std::boxed::Box;
use std::future::Future;
use std::pin::Pin;
use tonic::transport::Channel;
use crate::hkservice::home_kit_service_client::HomeKitServiceClient;
use crate::hkservice::{EnumerateActionSetsRequest, EnumerateActionSetsResponse};
use crate::hkservice::action_set_information::ActionSetType;
use crate::hkservice::action_set_information::action::Action;
use crate::services::print_characteristic;

impl std::fmt::Display for ActionSetType {
    fn fmt(&self, f: &mut std::fmt::Formatter) -> std::fmt::Result {
        write!(f, "{:?}", self)
    }
}

fn print_response(response: &EnumerateActionSetsResponse) {
    if let Some(ref home) = &response.home {
        println!("Home: {}", home.name);
    }
    println!("Action Sets ({}):", response.action_sets.len());
    response.action_sets.iter().for_each(|action_set| {
        println!("  Action Set: {}", action_set.name);
        println!("    UUID: {}", action_set.uuid);
        println!("    Type: {}", action_set.action_set_type());
        println!("    Is Executing: {}", action_set.is_executing);
        println!("    Actions: ({})", action_set.actions.len());
        action_set.actions.iter().for_each(|action| {
            if let Some(ref action) = action.action {
                println!("      Action:");
                match action {
                    Action::GenericAction(ga) => {
                        println!("        UUID: {}", ga.uuid);
                    },
                    Action::CharacteristicAction(ca) => {
                        println!("        UUID: {}", ca.uuid);
                        if let Some(ref c) = ca.characteristic {
                            print_characteristic(&c, 8);
                        }
                    },
                };
            }
        });
    });
}

async fn _run(matches: ArgMatches, mut client: HomeKitServiceClient<Channel>) -> Result<(), Box<dyn std::error::Error>> {
    let response = client.enumerate_action_sets(
        EnumerateActionSetsRequest {
            home: matches.value_of("home").unwrap_or("").to_string(),
            name_filter: matches.value_of("name").unwrap_or("").to_string(),
        }).await?.into_inner();
    print_response(&response);
    Ok(())
}

pub fn run(matches: ArgMatches, client: HomeKitServiceClient<Channel>) -> Pin<Box<dyn Future<Output = Result<(), Box<dyn std::error::Error>>>>> {
    Box::pin(_run(matches, client))
}
