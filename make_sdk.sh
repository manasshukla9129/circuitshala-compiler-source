#!/usr/bin/env bash
# Collects everything the phone needs besides the three programs into one folder
# (packed into assets/toolchain/avr-sdk.tar.gz): headers, startup code, libraries
# and the precompiled Arduino core.
# Usage: make_sdk.sh <avr toolchain prefix> <ArduinoCore-avr dir> <core.a> <out dir>
set -euo pipefail
PREFIX="$1"; CORE="$2"; COREA="$3"; OUT="$4"
GCCLIB="$PREFIX/lib/gcc/avr/14.2.0"
rm -rf "$OUT"; mkdir -p "$OUT/include/gcc" "$OUT/include/avr-libc" "$OUT/include/arduino" "$OUT/include/variant" "$OUT/lib"
cp -R "$GCCLIB/include/." "$OUT/include/gcc/"
cp -R "$PREFIX/avr/include/." "$OUT/include/avr-libc/"
cp "$CORE"/cores/arduino/*.h "$OUT/include/arduino/"
cp "$CORE"/variants/standard/*.h "$OUT/include/variant/"
# Library headers, keeping sub-folders (Servo.h includes "avr/ServoTimers.h").
LIBS="$(cd "$(dirname "$0")" && pwd)/libraries"
for d in "$LIBS"/*/; do (cd "$d" && find . -name '*.h' -exec rsync -R {} "$OUT/include/arduino/" \;); done
for lib in SoftwareSerial SPI EEPROM Wire; do cp "$CORE/libraries/$lib/src"/*.h "$OUT/include/arduino/"; done
cp "$PREFIX/avr/lib/avr5/crtatmega328p.o" "$PREFIX/avr/lib/avr5/libc.a" "$PREFIX/avr/lib/avr5/libm.a" \
   "$PREFIX/avr/lib/avr5/libatmega328p.a" "$GCCLIB/avr5/libgcc.a" "$COREA" "$OUT/lib/"
cp "$PREFIX/avr/lib/ldscripts/avr5.xn" "$OUT/lib/" # this ld reads its default script from a file
# avr-libc ships register headers for ~340 chips; the Uno only needs the ATmega328P one.
find "$OUT/include/avr-libc/avr" -name 'io?*.h' ! -name 'iom328p.h' -delete
rm -rf "$OUT/include/gcc/ssp" 2>/dev/null || true
"$PREFIX/bin/avr-strip" --strip-debug "$OUT"/lib/*.a "$OUT"/lib/*.o # debug info is useless on the phone
du -sh "$OUT" "$OUT"/lib/*
