#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
export PATH="/opt/homebrew/opt/rustup/bin:$HOME/.cargo/bin:$PATH"
"$ROOT/scripts/bootstrap-deadbolt.sh"
MODE=${1:-all}
current() {
  [ "${DEADBOLT_FORCE_RUST_BUILD:-0}" != 1 ] || return 1
  ARCHIVE="$ROOT/RustBridge/lib/$1/libdeadbolt_ios.a"
  [ -f "$ARCHIVE" ] || return 1
  [ "$ARCHIVE" -nt "$ROOT/RustBridge/Cargo.toml" ] || return 1
  [ "$ARCHIVE" -nt "$ROOT/RustBridge/Cargo.lock" ] || return 1
  [ -z "$(find "$ROOT/RustBridge/src" "$ROOT/RustBridge/patches" "$ROOT/vendor/deadbolt/crates/core" "$ROOT/vendor/deadbolt/crates/store" "$ROOT/vendor/deadbolt/crates/net" -type f ! -path "$ROOT/RustBridge/src/tests.rs" -newer "$ARCHIVE" -print -quit)" ]
}
build() {
  TARGET=$1
  SDK=$2
  SDKROOT=$(xcrun --sdk "$SDK" --show-sdk-path)
  export SDKROOT
  cargo build --locked --release --manifest-path "$ROOT/RustBridge/Cargo.toml" --target "$TARGET"
}
if [ "$MODE" = all ] || [ "$MODE" = iphoneos ]; then
  if ! current iphoneos; then
  build aarch64-apple-ios iphoneos
  mkdir -p "$ROOT/RustBridge/lib/iphoneos"
  cp "$ROOT/RustBridge/target/aarch64-apple-ios/release/libdeadbolt_ios.a" "$ROOT/RustBridge/lib/iphoneos/"
  fi
fi
if [ "$MODE" = all ] || [ "$MODE" = iphonesimulator ]; then
  if ! current iphonesimulator; then
  build aarch64-apple-ios-sim iphonesimulator
  mkdir -p "$ROOT/RustBridge/lib/iphonesimulator"
  cp "$ROOT/RustBridge/target/aarch64-apple-ios-sim/release/libdeadbolt_ios.a" "$ROOT/RustBridge/lib/iphonesimulator/"
  fi
fi
