use build_deps;
use tonic_build;

fn main() -> Result<(), Box<dyn std::error::Error>> {
    tonic_build::compile_protos("../protos/hkserver.proto")?;
    build_deps::rerun_if_changed_paths("../protos/hkserver.proto").unwrap();

    // Inject build project as cfg "profile" key
    println!("cargo:rustc-cfg=profile=\"{}\"", std::env::var("PROFILE").unwrap());

    Ok(())
}
