use tonic_build;

fn main() -> Result<(), Box<dyn std::error::Error>> {
    tonic_build::compile_protos("../protos/hkserver.proto")?;

    // Inject build project as cfg "profile" key
    println!("cargo:rustc-cfg=profile=\"{}\"", std::env::var("PROFILE").unwrap());

   Ok(())
}
