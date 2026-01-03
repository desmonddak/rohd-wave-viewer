# Building wellen_bridge

## Rust Toolchain Requirements

This project requires **two different Rust toolchains** due to dependency constraints:

### 1. Rust 1.80 - For Building flutter_rust_bridge_codegen

The `flutter_rust_bridge_codegen` code generator (version 2.6.0) has dependencies that fail to compile under newer Rust versions in this environment. Use Rust 1.80 to build and install the code generator:

```tcsh
# Install Rust 1.80 toolchain
~/.rustup/toolchains/1.80.0-x86_64-unknown-linux-gnu/bin/cargo install flutter_rust_bridge_codegen --version 2.6.0 --locked
```

Or if using rustup:

```tcsh
rustup install 1.80.0
cargo +1.80.0 install flutter_rust_bridge_codegen --version 2.6.0 --locked
```

### 2. Rust 1.92+ (stable) - For Building wellen_bridge Library

The wellen library (v0.20.1) requires:

- Rust 1.90.0+ for wellen itself
- Edition 2024 support (requires Rust 1.92+)
- Various dependencies requiring Rust 1.80+

**Build the library using Rust stable (1.92):**

```tcsh
# Set stable toolchain in PATH
setenv PATH ~/.rustup/toolchains/stable-x86_64-unknown-linux-gnu/bin:$PATH

# Build the library
cd /path/to/rust/wellen_bridge
cargo build --release
```

## Generating Dart FFI Bindings

After installing the code generator with Rust 1.80, use it to generate Dart bindings. **Important**: Set PATH to use Rust stable so cargo expand can compile the wellen crate:

```tcsh
cd /home/ganewto/src/rohd/rohd-wave-viewer
setenv PATH ~/.rustup/toolchains/stable-x86_64-unknown-linux-gnu/bin:$PATH

~/.cargo/bin/flutter_rust_bridge_codegen generate \
  --rust-input crate::api \
  --rust-root rust/wellen_bridge \
  --dart-output packages/rohd_wellen/lib/src/rust \
  --rust-output rust/wellen_bridge/src/frb_generated.rs
```

Note: Do not use --config-file with relative paths; command-line arguments work more reliably from the workspace root.

## Building the Flutter Linux App

```tcsh
cd /home/ganewto/src/rohd/rohd-wave-viewer

# Build Flutter app
flutter build linux --debug

# Set LD_LIBRARY_PATH to point to the Rust library (set once per shell session)
setenv LD_LIBRARY_PATH /home/ganewto/src/rohd/rohd-wave-viewer/rust/wellen_bridge/target/release

# Run the app with absolute path
/home/ganewto/src/rohd/rohd-wave-viewer/build/linux/x64/debug/bundle/rohd_wave_viewer /home/ganewto/src/rohd/rohd-wave-viewer/surfer/examples/picorv32.vcd &
```

**Note**: Using `LD_LIBRARY_PATH` eliminates the need to copy `libwellen_bridge.so` after each Rust rebuild, making the development iteration much faster. The environment variable only needs to be set once per shell session.

## Summary

1. **Install codegen**: Use Rust 1.80 (one-time)
2. **Generate bindings**: Use Rust stable in PATH (after changing api.rs)
3. **Build library**: Use Rust 1.92+ (stable)
4. **Build Flutter app**: `flutter build linux --debug`
5. **Set library path**: `setenv LD_LIBRARY_PATH /path/to/rust/target/release` (once per shell)
6. **Run app**: Use absolute path to executable

## Troubleshooting

- If cargo is using the wrong version, check `cargo --version`
- System cargo may be older (1.75); ensure ~/.rustup/toolchains/stable-x86_64-unknown-linux-gnu/bin is in PATH
- The codegen only needs to be installed once
- Regenerate bindings after changing api.rs
- Use `LD_LIBRARY_PATH` to avoid copying libwellen_bridge.so after each Rust rebuild
- In tcsh, use `setenv PATH` and `setenv LD_LIBRARY_PATH` not `export`

## Cleaning The Rust Build and Running Tests

When you need to completely clean the `wellen_bridge` crate (for example
after switching toolchains or to resolve mysterious incremental-build
problems), use the following steps. These commands work in `tcsh` as used in
this workspace; equivalent `bash` commands are also shown where appropriate.

1) Clean with cargo (recommended):

```tcsh
cd /home/ganewto/src/rohd/rohd-wave-viewer/rust/wellen_bridge
cargo clean
```

Or, if you built with a specific toolchain, run:

```tcsh
rustup run 1.92.0 cargo clean
# or
cargo +1.92.0 clean
```

1) Remove the `target/` directory (forceful):

```tcsh
rm -rf /home/ganewto/src/rohd/rohd-wave-viewer/rust/wellen_bridge/target
```

1) (Optional) Remove any copied native libraries in the Flutter bundle if you previously used the copy method:

```tcsh
rm -f /home/ganewto/src/rohd/rohd-wave-viewer/build/linux/x64/debug/bundle/lib/libwellen_bridge.so
```

1) (Optional) Clean Flutter build artifacts if you want a full rebuild:

```tcsh
cd /home/ganewto/src/rohd/rohd-wave-viewer
flutter clean
rm -rf build/
```

1) Rebuild the Rust library:

```tcsh
cd /home/ganewto/src/rohd/rohd-wave-viewer/rust/wellen_bridge
setenv PATH ~/.rustup/toolchains/stable-x86_64-unknown-linux-gnu/bin:$PATH
cargo build --release
```

1) Rebuild and run the Flutter app using LD_LIBRARY_PATH:

```tcsh
cd /home/ganewto/src/rohd/rohd-wave-viewer
flutter build linux --debug

# Set library path (once per shell session)
setenv LD_LIBRARY_PATH /home/ganewto/src/rohd/rohd-wave-viewer/rust/wellen_bridge/target/release

# Run with absolute path
/home/ganewto/src/rohd/rohd-wave-viewer/build/linux/x64/debug/bundle/rohd_wave_viewer /home/ganewto/src/rohd/rohd-wave-viewer/surfer/examples/picorv32.vcd &
```

Running unit/widget tests:

- To run the project's Dart tests (including the rohd_module page tests), use
  the regular `flutter test` command from the workspace root.

```tcsh
cd /home/ganewto/src/rohd/rohd-wave-viewer
flutter test
```

- If a test is intentionally skipped (for example `skip: true` in a
  `testWidgets`), enable it by removing the `skip` flag or setting it to
  `false`. The test file `test/modules/rohd_module/view/rohd_module_page_test.dart`
  contains a `skip: true` marker with a `TODO: enable this test!` comment.

  After enabling the test, run `flutter test` and inspect failures. If tests
  depend on native FFI output (wellen), prefer mocking the `ModuleStructureApi`
  in tests rather than invoking the native library.
