#!/bin/sh

# Add --release for release builds
xargo build --target x86_64-apple-ios-macabi $*

