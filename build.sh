#!/bin/sh

set -e
set -x

# When building using a standard/nightly toolchain, +nightly -Z build-std must
# be used
#cargo +nightly build -Z build-std --target x86_64-apple-ios-macabi $*

# When building with a local toolchain, it's not necessary since the local
# toolchain build can include std (and only nightly cargo supports -Z
# build-std).
cargo build $*

# Use cargo-bundle to build and package the .app for the server. It requires
# using a --target argument regardless of whether .cargo/config.toml exists.
cargo bundle --target x86_64-apple-ios-macabi --bin server $*

# Code sign
codesign --entitlements entitlements.plist -s \
         $(security find-identity -v -p codesigning | awk '{print $2}' | head -n 1) \
         ./target/x86_64-apple-ios-macabi/debug/bundle/osx/hkserver.app/Contents/MacOS/server

