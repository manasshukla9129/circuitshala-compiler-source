#!/usr/bin/env bash
# Copies the built compiler into the app: the three programs as native libraries
# (Android only lets apps run programs from there) and the SDK as an asset.
# Usage: install_into_app.sh <work dir of build_toolchain.sh>   (run from the app folder)
set -euo pipefail
WORK="$(cd "$1" && pwd)"
NDKBIN="${NDK:-$HOME/Library/Android/sdk/ndk/28.2.13676358}/toolchains/llvm/prebuilt/darwin-x86_64/bin"
for abi in arm64-v8a:android-arm64 armeabi-v7a:android-armv7 x86_64:android-x86_64; do
  dir="${abi%%:*}"; src="$WORK/${abi##*:}"
  [ -x "$src/cc1plus" ] || continue
  mkdir -p "android/app/src/main/jniLibs/$dir"
  cp "$src/cc1plus" "android/app/src/main/jniLibs/$dir/libavr_cc1plus.so"
  cp "$src/bin/avr-as" "android/app/src/main/jniLibs/$dir/libavr_as.so"
  cp "$src/bin/avr-ld" "android/app/src/main/jniLibs/$dir/libavr_ld.so"
  "$NDKBIN/llvm-strip" "android/app/src/main/jniLibs/$dir"/libavr_*.so
done
mkdir -p assets/toolchain
tar -czf assets/toolchain/avr-sdk.tar.gz -C "$WORK/sdk" .
ls -la android/app/src/main/jniLibs/* assets/toolchain
