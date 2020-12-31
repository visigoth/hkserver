use tonic::transport::Server;
use tokio;

mod hkservice;

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    let addr: std::net::SocketAddr = "127.0.0.1:55123".parse().unwrap();
    let service = hkservice::HKServer::new();
    Server::builder()
        .add_service(hkservice::HomeKitServiceServer::new(service))
        .serve(addr)
        .await?;
    Ok(())
}
