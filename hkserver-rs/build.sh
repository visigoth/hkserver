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
#codesign --force --entitlements entitlements.plist -o runtime \
#         --sign $(security find-identity -v -p codesigning | awk '{print $2}' | head -n 1) \
#         --timestamp=none \
#         ./target/x86_64-apple-ios-macabi/debug/bundle/osx/hkserver.app/Contents/MacOS/server

#codesign --force --entitlements entitlements.plist -o runtime \
#         --sign $(security find-identity -v -p codesigning | awk '{print $2}' | head -n 1) \
#         --timestamp \
#         ./target/x86_64-apple-ios-macabi/debug/bundle/osx/hkserver.app

codesign --force --deep -o runtime \
         --entitlements entitlements.plist \
         --sign 7E2DE1CF161741E61566CC765BC18B0F9B031977 \
         --timestamp \
         ./target/x86_64-apple-ios-macabi/debug/bundle/osx/hkserver.app

#xcnotary notarize target/x86_64-apple-ios-macabi/debug/bundle/osx/hkserver.app --developer-account "shaheen@brokenrobotllc.com" --developer-password-keychain-item AC_PASSWORD

# Need to register with launch services
/System/Library/Frameworks/CoreServices.framework/Versions/Current/Frameworks/LaunchServices.framework/Versions/Current/Support/lsregister -f -R -trusted -v ./target/x86_64-apple-ios-macabi/debug/bundle/osx/hkserver.app
