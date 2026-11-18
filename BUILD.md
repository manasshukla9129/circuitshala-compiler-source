# On-phone AVR compiler (Step 3)

The app compiles the student's sketch on the phone, offline:

```
sketch.ino ─(Dart: ino_preprocessor)→ sketch.cpp ─cc1plus→ sketch.s ─as→ sketch.o
  ─ld (+ core.a, avr-libc, libgcc)→ sketch.elf ─(Dart: elf_to_hex)→ HEX → simulator
```

What ships in the APK:

| File | What | Size |
|---|---|---|
| `android/app/src/main/jniLibs/arm64-v8a/libavr_cc1plus.so` | GCC 14.2 C++ compiler for AVR, built to run on Android | 24.5 MB |
| `.../libavr_as.so`, `.../libavr_ld.so` | GNU as / ld 2.43 for AVR | 1.2 + 1.4 MB |
| `assets/toolchain/avr-sdk.tar.gz` | headers (gcc, avr-libc for the ATmega328P, Arduino core), `core.a` (Arduino core 1.8.6, precompiled without LTO), avr-libc/libgcc libraries, linker script | 0.5 MB (3.2 MB unpacked) |

The programs are named `lib*.so` because Android only lets an app run programs
from its native library folder; `useLegacyPackaging` in `build.gradle.kts` makes
Android unpack them as real files. The SDK is unpacked once to the app's support
folder (`NativeSketchCompiler.sdkVersion` forces a fresh unpack after updates).

## Rebuilding

Sources (official releases): gcc-14.2.0, binutils-2.43, gmp-6.3.0, mpfr-4.2.1,
mpc-1.3.1 (ftp.gnu.org), avr-libc-2.2.1 (github.com/avrdudes/avr-libc),
ArduinoCore-avr 1.8.6 (github.com/arduino/ArduinoCore-avr). Put the archives in
`<work>/src`; the work folder path must not contain spaces (GNU configure).

```bash
tool/toolchain/build_toolchain.sh ~/circuitlab-toolchain-build mac avrlibc android-arm64   # ~40 min
tool/toolchain/build_core.sh ~/circuitlab-toolchain-build/mac ~/circuitlab-toolchain-build/src/ArduinoCore-avr-1.8.6 ~/circuitlab-toolchain-build/probe
tool/toolchain/make_sdk.sh ~/circuitlab-toolchain-build/mac ~/circuitlab-toolchain-build/src/ArduinoCore-avr-1.8.6 ~/circuitlab-toolchain-build/probe/core.a ~/circuitlab-toolchain-build/sdk
tool/toolchain/install_into_app.sh ~/circuitlab-toolchain-build          # run from the app folder
```

Notes: GCC needs `--enable-host-pie` for Android (otherwise lld rejects absolute
relocations); bundled zlib needs a one-line fix for new macOS SDKs (done by the
script); `makeinfo` is not needed (`MAKEINFO=true`).

32-bit ARM phones: `android-armv7` stage (built and shipped under jniLibs/armeabi-v7a). Add `android-x86_64` to the build for x86 emulators / Chromebooks. Phones without
a shipped compiler fall back to the bundled examples, and the board still powers on.

## Licences

GCC and GNU binutils are GPL-3.0 (GCC's runtime library exception covers
libgcc); avr-libc is BSD-style; the Arduino AVR core is LGPL-2.1. When the app
is distributed, the exact sources above (and these build scripts) must be
offered with it, e.g. by publishing them next to the release.
