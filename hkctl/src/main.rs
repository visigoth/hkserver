mod hkservice;
mod homes;
mod rooms;
mod zones;

use clap::{App, Arg, crate_version};
use tonic::transport::{Channel, Uri};
use tokio;
use hkservice::home_kit_service_client::HomeKitServiceClient;
use std::error::Error;

impl HomeKitServiceClient<Channel> {
    async fn create(host: &str, port: u32) -> Result<HomeKitServiceClient<Channel>, Box<dyn Error>> {
        let authority = format!("{}:{}", host, port);
        let endpoint = Uri::builder()
            .scheme("http")
            .authority(authority.as_str())
            .path_and_query("/")
            .build();
        let channel = tonic::transport::Channel::builder(endpoint.unwrap())
            .connect()
            .await?;
        Ok(HomeKitServiceClient::new(channel))
    }
}

#[tokio::main]
async fn main() -> Result<(), Box<dyn Error>> {
    let mut app = App::new("hkctl")
        .version(crate_version!())
        .about("Command line porcelain for HomeKit")
        .arg(Arg::new("v")
             .short('v')
             .multiple(true)
             .about("Sets verbosity"))
        .arg(Arg::new("port")
             .long("port")
             .short('p')
             .value_name("PORT")
             .about("Local port to connect to"))
        .arg(Arg::new("home")
             .long("home")
             .about("Specify a home. Defaults to the primary home")
             .value_name("NAME OR UUID")
             .global(true))
        .subcommand(App::new("homes")
                    .about("Lists homes"))
        .subcommand(App::new("rooms")
                    .about("Lists rooms")
                    .arg(Arg::new("name")
                         .long("name")
                         .value_name("NAME OR UUID")
                         .about("Name pattern filter")))
        .subcommand(App::new("zones")
                    .about("Lists zones")
                    .arg(Arg::new("room")
                         .long("room")
                         .value_name("NAME OR UUID")
                         .about("Room name pattern filter"))
                    .arg(Arg::new("name")
                         .long("name")
                         .value_name("NAME OR UUID")
                         .about("Name pattern filter")));

    let matches = app.get_matches_mut();
    let port = match matches.value_of_t::<u32>("port") {
        Ok(port) => port,
        Err(e) => {
            if e.kind == clap::ErrorKind::ArgumentNotFound {
                55123
            } else {
                e.exit()
            }
        }
    };
    let client = HomeKitServiceClient::create("127.0.0.1", port).await?;

    let subcommand_fn = matches.subcommand_name().map(|name| {
        match name {
            "homes" => homes::run,
            "rooms" => rooms::run,
            "zones" => zones::run,
            _ => panic!("Unrecognized subcommand name")
        }
    });

    if let Some(subcommand_fn) = subcommand_fn {
        let args = matches.subcommand_matches(matches.subcommand_name().unwrap()).unwrap();
        let result = subcommand_fn(args.clone(), client).await;
        if let Err(ref error) = result {
            match error.downcast_ref::<tonic::Status>() {
                Some(e) => {
                    println!("Error returned by server: {}", e);
                    return result
                },
                None => return result,
            }
        }
    } else {
        app.print_help()?;
    }
    Ok(())
}
