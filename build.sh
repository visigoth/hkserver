#!/bin/bash

set -e

# First build swift grpc plugins
pushd third-party/grpc-swift && make plugins && popd

# Ensure protoc and plugins are on the path
export PATH=$(pwd)/third-party/protoc/bin:$(pwd)/third-party/grpc-swift:$PATH

# Generate protobuf and grpc code
mkdir -p gen
protoc --proto_path=protos --swift_out=protos/swift/hkrpc/Sources protos/hkserver.proto
protoc --proto_path=protos --grpc-swift_out=protos/swift/hkrpc/Sources protos/hkserver.proto

# Build the project
xcodebuild -workspace hkserver.xcworkspace -scheme hkserver
