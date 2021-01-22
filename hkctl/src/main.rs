mod hkservice;
mod homes;

use clap::{App, Arg, crate_version, value_t};
use tonic::transport::Uri;
use tokio;
use hkservice::home_kit_service_client::HomeKitServiceClient;

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    let matches = App::new("hkctl")
        .version(crate_version!())
        .about("Command line porcelain for HomeKit")
        .arg(Arg::with_name("v")
             .short("c")
             .multiple(true)
             .help("Sets verbosity"))
        .arg(Arg::with_name("port")
             .short("p")
             .help("Local port to connect to"))
        .arg(Arg::with_name("home")
             .help("Specify a home. Defaults to the primary home"))
        .subcommand(App::new("homes")
                    .about("Lists homes"))
        .get_matches();

    let port = value_t!(matches, "port", u32).unwrap_or(55123);
    let authority = format!("127.0.0.1:{}", port);
    let endpoint = Uri::builder()
        .scheme("http")
        .authority(authority.as_str())
        .build();
    let channel = tonic::transport::Channel::builder(endpoint.unwrap())
        .connect()
        .await?;
    let client = HomeKitServiceClient::new(channel);

    match matches.subcommand_name() {
        Some("homes") => {
            homes::command(matches.subcommand_matches("homes").unwrap(), client).await;
        },
        _ => {
            println!("oijasdoj");
        }
    }
    Ok(())
}
