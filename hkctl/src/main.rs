mod hkservice;
mod homes;

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
             .short('c')
             .multiple(true)
             .about("Sets verbosity"))
        .arg(Arg::new("port")
             .short('p')
             .about("Local port to connect to"))
        .arg(Arg::new("home")
             .about("Specify a home. Defaults to the primary home"))
        .subcommand(App::new("homes")
                    .about("Lists homes"));

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

    match matches.subcommand_name() {
        Some("homes") => {
            homes::command(matches.subcommand_matches("homes").unwrap(), client).await.unwrap();
        },
        _ => {
            app.print_help()?
        }
    }
    Ok(())
}
