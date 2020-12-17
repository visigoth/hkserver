use tonic::transport::Server;
use tokio;

mod hkserver {
    tonic::include_proto!("org.hkserver");

fn main() {
    println!("Hello, world!");
}
