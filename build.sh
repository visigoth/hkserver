#!/bin/sh

# When building using a standard/nightly toolchain, +nightly -Z build-std must
# be used
#cargo +nightly build -Z build-std --target x86_64-apple-ios-macabi $*

# When building with a local toolchain, it's not necessary since the local
# toolchain build can include std (and only nightly cargo supports -Z
# build-std).
cargo build $*
