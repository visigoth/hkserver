use clap::{Arg, App, crate_version, crate_description};
use tonic::transport::Server;
use tokio;

mod hkservice;

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    let matches = App::new("HKServer")
        .version(crate_version!())
        .about(crate_description!())
        .get_matches();

    let addr: std::net::SocketAddr = "127.0.0.1:55123".parse().unwrap();
    let service = hkservice::HKServer::new();
    Server::builder()
        .add_service(hkservice::HomeKitServiceServer::new(service))
        .serve(addr)
        .await?;
    Ok(())
}
