A gRPC server for HomeKit management.

While Apple does not ship a HomeKit framework on OSX directly, it does ship one with Mac OSX Big Sur for Mac Catalyst apps. Thus, this application is built for Mac Catalyst.

Since Mac Catalyst is treated as a tier 3 platform for rust, there are a number of changes needed in the project's dependencies, including a custom compiler.

# Building

## Toolchain

Until [this issue](https://github.com/rust-lang/rust/pull/80215) is resolved, `rustc` does not pass the correct arguments to the linker when linking Mac Catalyst binaries. Luckily, building your own toolchain is not that difficult.

Note that the target triple for Mac Catalyst is `x86_64-apple-ios-macabi`, which essentially means you need to build your compiler for cross-compilation support. Also, because some dependencies rely on `rustfmt` being available in your custom toolchain, you will need to build the tools as well as install the toolchain to a custom location, 

Follow along with [the instructions](https://rustc-dev-guide.rust-lang.org/building/how-to-build-and-run.html), but substitute the following in each of the steps.

Clone the compiler source with `git clone https://github.com/visigoth/rust.git -b issue-80202-fix`.

Customize `config.toml` with the following patch. `debug-logging` is not required:

```
> diff config.toml.example config.toml
152c152
< #build-stage = 1
---
> build-stage = 2
186c186
< #target = ["x86_64-unknown-linux-gnu"]
---
> target = ["x86_64-apple-darwin", "x86_64-apple-ios-macabi"]
253c253
< #extended = false
---
> extended = true
258a259
> tools = ["cargo", "rls", "clippy", "rustfmt", "analysis", "src"]
297c298
< #prefix = "/usr/local"
---
> prefix = "/some/other/path/.myrust"
301c302
< #sysconfdir = "/etc"
---
> sysconfdir = "etc"
```

You will need to build both `rustc` and `std` at stage 2, and then install and link the toolchain.

```bash
> ./x.py build compiler/rustc
...
> ./x.py build library/std
...
> ./x.py install
> rustup toolchain link myrust /some/other/path/.myrust
```

## Build

Ensure the toolchain is set prior to invoking `build.sh`.

```bash
> rustup override set myrust
> ./build.sh
```

# Running

Running the executable directly will crash because the system does not find `Info.plist` and the usage description correctly. The server can only be started with `open`.

```bash
> open target/x86_64-apple-ios-macabi/debug/bundle/osx/hkserver.app
```

The first time you run it, you should see a prompt asking for access to HomeKit data.

# Debugging

Since running the executable directly will crash, the only way to debug is to start the app with `--debug`:

```bash
> open target/x86_64-apple-ios-macabi/debug/bundle/osx/hkserver.app --debug
```

