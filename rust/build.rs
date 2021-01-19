use std::process::Command;
use std::path::{Path, PathBuf};
use tonic_build;

fn main() -> Result<(), Box<dyn std::error::Error>> {
    tonic_build::compile_protos("../protos/hkserver.proto")?;

    // Inject build project as cfg "profile" key
    println!("cargo:rustc-cfg=profile=\"{}\"", std::env::var("PROFILE").unwrap());

    // When building for Mac Catalyst, query the Xcode toolchain and set linker
    // flags as appropriate.
    let triple = std::env::var("TARGET").unwrap();
    if triple.contains("macabi") {
        let mut output = String::from_utf8(
            Command::new("xcode-select")
                .args(&["-p"])
                .output()
                .expect("Failed to execute xcode-select")
                .stdout
        ).expect("Non-UTF8 result from xcode-select -p");
        output.pop();
        let xcode_path = PathBuf::from(output);
        let ios_usr_lib = xcode_path.join("Platforms/MacOSX.platform/Developer/SDKs/MacOSX11.0.sdk/System/iOSSupport/usr/lib");
        let swift_lib = xcode_path.join("Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/maccatalyst");
        let catalyst_frameworks = xcode_path.join("Platforms/MacOSX.platform/Developer/SDKs/MacOSX11.0.sdk/System/iOSSupport/System/Library/Frameworks");

        println!("cargo:rustc-link-search=native={}", ios_usr_lib.to_str().unwrap());
        println!("cargo:rustc-link-search=native={}", swift_lib.to_str().unwrap());
        println!("cargo:rustc-link-search=framework={}", catalyst_frameworks.to_str().unwrap());
    }
    Ok(())
}
