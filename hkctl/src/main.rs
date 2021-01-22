tonic::include_proto!("org.hkserver");

use tokio;
use home_kit_service_client::HomeKitServiceClient;

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    let channel = tonic::transport::Channel::from_static("http://127.0.0.1:55123")
        .connect()
        .await?;
    let mut client = HomeKitServiceClient::new(channel);
    let response = client.enumerate_devices(
        EnumerateDevicesRequest {
            name_filter: String::from("")
        }).await?.into_inner();
    println!("RESPONSE={:?}", response);
    Ok(())
}
