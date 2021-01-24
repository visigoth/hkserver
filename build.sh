#!/bin/bash

set -e

# First build swift grpc plugins
pushd third-party/grpc-swift && make plugins && popd

# Ensure protoc and plugins are on the path
export PATH=$(pwd)/third-party/protoc/bin:$(pwd)/third-party/grpc-swift:$PATH

# Generate protobuf and grpc code
mkdir -p gen
protoc --experimental_allow_proto3_optional --proto_path=protos --swift_out=protos/swift protos/hkserver.proto
protoc --experimental_allow_proto3_optional --proto_path=protos --grpc-swift_out=protos/swift protos/hkserver.proto

# Build the project
xcodebuild -workspace hkutils.xcworkspace -scheme hkserver
pushd hkctl && cargo build && popd
