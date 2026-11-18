#!/usr/bin/env bash
# Builds the AVR compiler that ships inside the app (Step 3: compile on the phone).
#
#   1. mac:      binutils + gcc for macOS -> avr   (used here to build the AVR
#                libraries and the precompiled Arduino core)
#   2. avrlibc:  avr-libc with that compiler
#   3. android:  binutils (as, ld) + gcc (cc1plus) that RUN ON ANDROID and
#                produce AVR code, built with the Android NDK
#
# Usage: build_toolchain.sh <work dir> [stage...]   (stages: mac avrlibc android-arm64 android-armv7 android-x86_64)
# Sources are expected in <work dir>/src (see README in this folder).
set -euo pipefail

WORK="$(cd "$1" && pwd)"; shift
STAGES="${*:-mac avrlibc android-arm64}"
SRC="$WORK/src"; BUILD="$WORK/build"; MAC="$WORK/mac"
NDK="${NDK:-$HOME/Library/Android/sdk/ndk/28.2.13676358}"
NDKBIN="$NDK/toolchains/llvm/prebuilt/darwin-x86_64/bin"
API=24
JOBS="${JOBS:-$(sysctl -n hw.ncpu)}"
GCC=gcc-14.2.0; BINUTILS=binutils-2.43; AVRLIBC=avr-libc-2.2.1
GMP=gmp-6.3.0; MPFR=mpfr-4.2.1; MPC=mpc-1.3.1
export MAKEINFO=true # no docs

unpack() { # unpack <archive base name>
  [ -d "$SRC/$1" ] && return
  local f; f=$(ls "$SRC/$1".tar.* | head -1)
  tar -xf "$f" -C "$SRC"
}

prepare_sources() {
  for p in $GCC $BINUTILS $AVRLIBC $GMP $MPFR $MPC; do unpack "$p"; done
  # GCC builds its maths libraries in-tree when they sit next to its sources.
  ln -sfn "../$GMP" "$SRC/$GCC/gmp"
  ln -sfn "../$MPFR" "$SRC/$GCC/mpfr"
  ln -sfn "../$MPC" "$SRC/$GCC/mpc"
  # Bundled zlib breaks with newer macOS SDKs (it redefines fdopen when
  # TARGET_OS_MAC is set); only classic MacOS needs that workaround.
  for z in "$SRC/$BINUTILS/zlib/zutil.h" "$SRC/$GCC/zlib/zutil.h"; do
    sed -i '' 's/#if defined(MACOS) || defined(TARGET_OS_MAC)/#if defined(MACOS)/' "$z"
  done
}

COMMON_GCC_FLAGS=(--target=avr --enable-languages=c,c++ --disable-nls --disable-libssp --disable-libcc1
  --disable-shared --enable-static --with-dwarf2 --disable-plugin --disable-werror)

stage_mac() {
  mkdir -p "$BUILD/mac-binutils" "$BUILD/mac-gcc"
  (cd "$BUILD/mac-binutils" && "$SRC/$BINUTILS/configure" --target=avr --prefix="$MAC" --disable-nls \
      --disable-werror --disable-gdb --disable-gprofng --disable-sim && make -j"$JOBS" MAKEINFO=true && make MAKEINFO=true install)
  export PATH="$MAC/bin:$PATH"
  (cd "$BUILD/mac-gcc" && "$SRC/$GCC/configure" --prefix="$MAC" "${COMMON_GCC_FLAGS[@]}" && make -j"$JOBS" MAKEINFO=true && make MAKEINFO=true install-strip)
}

stage_avrlibc() {
  export PATH="$MAC/bin:$PATH"
  mkdir -p "$BUILD/avr-libc"
  (cd "$BUILD/avr-libc" && "$SRC/$AVRLIBC/configure" --host=avr --build="$("$SRC/$AVRLIBC/config.guess")" \
      --prefix="$MAC" && make -j"$JOBS" MAKEINFO=true && make MAKEINFO=true install)
}

stage_android() { # stage_android <ndk triple prefix> <output dir name>
  local triple=$1 out="$WORK/$2"
  export PATH="$MAC/bin:$PATH" # build-machine avr tools
  local cc="$NDKBIN/${triple}${API}-clang" cxx="$NDKBIN/${triple}${API}-clang++"
  local env=(CC="$cc" CXX="$cxx" AR="$NDKBIN/llvm-ar" RANLIB="$NDKBIN/llvm-ranlib" STRIP="$NDKBIN/llvm-strip"
    CFLAGS="-O2" CXXFLAGS="-O2" LDFLAGS="-static-libstdc++")
  mkdir -p "$BUILD/$2-binutils" "$BUILD/$2-gcc" "$out"
  [ -x "$out/bin/avr-ld" ] || (cd "$BUILD/$2-binutils" && env "${env[@]}" "$SRC/$BINUTILS/configure" --host="$triple" --target=avr \
      --prefix="$out" --disable-nls --disable-werror --disable-gdb --disable-gprofng --disable-sim \
      --disable-plugins --disable-lto && make -j"$JOBS" MAKEINFO=true all-gas all-ld && make MAKEINFO=true install-gas install-ld)
  (cd "$BUILD/$2-gcc" && env "${env[@]}" "$SRC/$GCC/configure" --build="$("$SRC/$GCC/config.guess")" \
      --host="$triple" --prefix="$out" "${COMMON_GCC_FLAGS[@]}" --disable-lto --enable-host-pie \
      && make -j"$JOBS" MAKEINFO=true all-gcc)
  local libexec; libexec=$(find "$BUILD/$2-gcc/gcc" -maxdepth 1 -name cc1plus)
  cp "$libexec" "$out/cc1plus"
  "$NDKBIN/llvm-strip" "$out/cc1plus" "$out/bin/avr-as" "$out/bin/avr-ld" 2>/dev/null || true
}

prepare_sources
for s in $STAGES; do
  echo "=== $s"
  case $s in
    mac) stage_mac ;;
    avrlibc) stage_avrlibc ;;
    android-arm64) stage_android aarch64-linux-android android-arm64 ;;
    android-armv7) stage_android armv7a-linux-androideabi android-armv7 ;;
    android-x86_64) stage_android x86_64-linux-android android-x86_64 ;;
    *) echo "unknown stage $s"; exit 1 ;;
  esac
done
