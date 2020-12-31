tonic::include_proto!("org.hkserver");

use tonic::{Request, Response, Status};
use home_kit_service_server::HomeKitService;
pub use home_kit_service_server::HomeKitServiceServer;
use fruity::home_kit::HMHomeManager;

pub struct HKServer {
}

impl HKServer {
    pub fn new() -> HKServer {
        let _home_manager = HMHomeManager::new();
        HKServer {}
    }
}

#[tonic::async_trait]
impl HomeKitService for HKServer {
    async fn enumerate_devices(&self, _request: Request<EnumerateDevicesRequest>) -> Result<Response<EnumerateDevicesResponse>, Status> {
        Ok(Response::new(EnumerateDevicesResponse {
            devices: vec![DeviceInformation {
                name: String::from("one")
            }]
        }))
    }
}
