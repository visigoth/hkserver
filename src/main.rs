use tonic::transport::Server;
use tokio;

mod hkserver {
    tonic::include_proto!("org.hkserver");

    use tonic::{Request, Response, Status};
    use home_kit_service_server::HomeKitService;
    pub use home_kit_service_server::HomeKitServiceServer;

    #[derive(Default)]
    pub struct HKServer {}

    #[tonic::async_trait]
    impl HomeKitService for HKServer {
        async fn enumerate_devices(&self, _request: Request<EnumerateDevicesRequest>) -> Result<Response<EnumerateDevicesResponse>, Status> {
            Ok(Response::new(EnumerateDevicesResponse {
                devices: vec![]
            }))
        }
    }

}

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    let addr: std::net::SocketAddr = "127.0.0.1:55123".parse().unwrap();
    let service = hkserver::HKServer::default();
    Server::builder()
        .add_service(hkserver::HomeKitServiceServer::new(service))
        .serve(addr)
        .await?;
    Ok(())
}
